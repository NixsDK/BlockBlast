//
//  GameViewModel.swift
//  BlockBlast
//
//  The single source of truth for everything game-logic. Lives on the main
//  actor so the views can read state without isolation hops.
//
//  Public surface (consumed by the views):
//    • `grid`               – 8x8 array of GridCell
//    • `tray`               – 3 optional shapes the player can drag
//    • `score`, `personalBest`, `comboStreak`
//    • `isGameOver`, `comboBurst`, `comboBurstToken`
//    • `previewCells`       – the highlighted cells under the dragged piece
//    • `canPlace`, `place`, `setPreview`, `clearPreview`, `restart`
//
//  Pure logic intentionally has no SwiftUI imports apart from `Color`, which
//  is part of the `BlockShape` model — making the brain straightforward to
//  unit-test.
//

import SwiftUI
import Combine

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var grid: [[GridCell]]
    @Published private(set) var tray: [BlockShape?] = [nil, nil, nil]

    @Published private(set) var score: Int = 0
    @Published private(set) var comboStreak: Int = 0
    @Published private(set) var lastClearCount: Int = 0

    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var newPersonalBestThisGame: Bool = false

    /// Set to a non-nil tuple when the player is mid-drag and the proposed
    /// placement is *valid*. The board view paints these cells as a ghost.
    @Published private(set) var previewCells: [(row: Int, col: Int)] = []
    @Published private(set) var previewColor: Color? = nil

    /// Token incremented every time we want to play the combo Lottie. Bind to
    /// `LottieView.playToken` to retrigger.
    @Published private(set) var comboBurstToken: Int = 0
    @Published private(set) var gameOverBurstToken: Int = 0

    // MARK: - Constants

    /// Single source of truth for the board dimension (8x8).
    static let boardSize = GridCell.boardSize

    /// Number of pieces visible in the tray at once.
    static let trayCapacity = 3

    /// Threshold at or above which the confetti combo Lottie plays.
    static let bigComboThreshold = 3

    // MARK: - Dependencies

    private let firebase: FirebaseManager

    // MARK: - Init

    init(firebase: FirebaseManager = .shared) {
        self.firebase = firebase
        self.grid = Self.makeEmptyGrid()
        refillTrayIfNeeded()
    }

    // MARK: - Lifecycle

    func restart() {
        grid = Self.makeEmptyGrid()
        tray = [nil, nil, nil]
        score = 0
        comboStreak = 0
        lastClearCount = 0
        previewCells = []
        previewColor = nil
        isGameOver = false
        newPersonalBestThisGame = false
        refillTrayIfNeeded()
    }

    // MARK: - Drag preview

    /// Update the ghost preview while the user drags a piece. Pass `nil` if
    /// the piece is currently off-board or in an invalid position so the
    /// view-model can clear the highlight.
    func setPreview(shape: BlockShape, originRow: Int, originCol: Int) {
        guard canPlace(shape: shape, atRow: originRow, col: originCol) else {
            clearPreview()
            return
        }
        previewCells = shape.filledOffsets.map { offset in
            (originRow + offset.row, originCol + offset.col)
        }
        previewColor = shape.color
    }

    func clearPreview() {
        previewCells = []
        previewColor = nil
    }

    // MARK: - Placement validation

    /// Returns true iff the shape can be placed with its top-left at `(row, col)`
    /// without leaving the board or colliding with filled cells.
    func canPlace(shape: BlockShape, atRow row: Int, col: Int) -> Bool {
        let size = Self.boardSize
        for offset in shape.filledOffsets {
            let r = row + offset.row
            let c = col + offset.col
            if r < 0 || r >= size || c < 0 || c >= size { return false }
            if grid[r][c].isFilled { return false }
        }
        return true
    }

    /// Returns true iff the shape can fit *anywhere* on the current board.
    /// Used for game-over detection.
    func canPlaceAnywhere(_ shape: BlockShape) -> Bool {
        let size = Self.boardSize
        for r in 0..<size {
            for c in 0..<size where canPlace(shape: shape, atRow: r, col: c) {
                return true
            }
        }
        return false
    }

    // MARK: - Placement

    /// Attempts to commit a placement. Returns true on success. On success
    /// the shape is removed from the tray, line clears + scoring run, the
    /// tray refills if empty, and game-over is checked.
    @discardableResult
    func place(trayIndex: Int, atRow row: Int, col: Int) -> Bool {
        guard tray.indices.contains(trayIndex),
              let shape = tray[trayIndex],
              canPlace(shape: shape, atRow: row, col: col) else {
            clearPreview()
            return false
        }

        // 1. Stamp the piece into the grid.
        for offset in shape.filledOffsets {
            let r = row + offset.row
            let c = col + offset.col
            grid[r][c].color = shape.color
        }
        score += shape.cellCount

        // 2. Resolve any completed rows or columns.
        let cleared = clearCompletedLines()
        applyScoring(forLinesCleared: cleared)

        // 3. Remove the placed piece from the tray.
        tray[trayIndex] = nil

        // 4. Refill the tray if all three pieces are consumed.
        refillTrayIfNeeded()

        // 5. Tear down the drag preview.
        clearPreview()

        // 6. Game over?
        evaluateGameOver()
        return true
    }

    // MARK: - Line clearing

    /// Detects and clears full rows and columns simultaneously. Returns the
    /// total number of lines cleared (rows + columns).
    private func clearCompletedLines() -> Int {
        let size = Self.boardSize
        var rowsToClear: [Int] = []
        var colsToClear: [Int] = []

        for r in 0..<size where grid[r].allSatisfy({ $0.isFilled }) {
            rowsToClear.append(r)
        }
        for c in 0..<size {
            var full = true
            for r in 0..<size where grid[r][c].isEmpty {
                full = false
                break
            }
            if full { colsToClear.append(c) }
        }

        // We collect coordinates first, then erase, so a square that lies on
        // a cleared row AND a cleared column doesn't cause double-counting
        // and the visual state is consistent.
        for r in rowsToClear { for c in 0..<size { grid[r][c].color = nil } }
        for c in colsToClear { for r in 0..<size { grid[r][c].color = nil } }

        return rowsToClear.count + colsToClear.count
    }

    // MARK: - Scoring

    /// Applies points and updates the combo streak/multiplier.
    ///
    /// Scoring rules (tweak to taste):
    ///   • 10 points per cleared cell (so a full row = 80 points base).
    ///   • Multi-line bonus multiplier scales with simultaneous lines:
    ///       1 line  → 1x
    ///       2 lines → 1.5x  (rounded up)
    ///       3 lines → 2x
    ///       4+      → 3x
    ///   • Consecutive turns with at least one clear stack a streak bonus
    ///     of `1 + streak * 0.25`.
    private func applyScoring(forLinesCleared lines: Int) {
        guard lines > 0 else {
            comboStreak = 0
            lastClearCount = 0
            return
        }

        let basePerCell = 10
        let baseScore = lines * Self.boardSize * basePerCell

        let multiLineMultiplier: Double
        switch lines {
        case 1:    multiLineMultiplier = 1.0
        case 2:    multiLineMultiplier = 1.5
        case 3:    multiLineMultiplier = 2.0
        default:   multiLineMultiplier = 3.0
        }

        let streakMultiplier = 1.0 + Double(comboStreak) * 0.25
        let earned = Int((Double(baseScore) * multiLineMultiplier * streakMultiplier).rounded())
        score += earned

        comboStreak += 1
        lastClearCount = lines

        if lines >= Self.bigComboThreshold {
            comboBurstToken &+= 1
        }
    }

    // MARK: - Tray management

    private func refillTrayIfNeeded() {
        if tray.allSatisfy({ $0 == nil }) {
            tray = (0..<Self.trayCapacity).map { _ in BlockShape.random() }
        }
    }

    // MARK: - Game-over evaluation

    /// Call after any drag ends (and after `place`). Without this, a full tray
    /// where **none** of the three shapes fits anywhere never triggers game over
    /// because the player never completes a successful placement.
    func checkForGameOverAfterPlayerInteraction() {
        evaluateGameOver()
    }

    private func evaluateGameOver() {
        guard !isGameOver else { return }

        let remaining = tray.compactMap { $0 }
        // The tray refill above guarantees `remaining` is non-empty unless
        // the player has cleared everything (in which case we keep playing).
        guard !remaining.isEmpty else { return }

        let anyFits = remaining.contains(where: { canPlaceAnywhere($0) })
        if !anyFits {
            clearPreview()
            isGameOver = true
            gameOverBurstToken &+= 1
            newPersonalBestThisGame = firebase.submitScoreIfPersonalBest(score)
        }
    }

    // MARK: - Helpers

    private static func makeEmptyGrid() -> [[GridCell]] {
        let size = boardSize
        return (0..<size).map { r in
            (0..<size).map { c in GridCell(row: r, col: c) }
        }
    }
}
