//
//  DraggableShapeView.swift
//  BlockBlast
//
//  Tray piece + drag gesture.
//  • `DragGesture(.global)` + `boardFrameInGlobal` → grid-local points (tray is
//    not under the grid’s coordinate space).
//  • **Cell size** is derived from the grid’s **on-screen width** so stride math
//    matches what `LazyVGrid` actually painted (preference alone can lag or
//    disagree after layout).
//

import SwiftUI
import UIKit

struct DraggableShapeView: View {

    let trayIndex: Int
    let shape: BlockShape

    @ObservedObject var viewModel: GameViewModel

    @Environment(\.boardCellSize) private var boardCellSizeFromPreference: CGFloat
    @Environment(\.boardFrameInGlobal) private var boardFrameInGlobal: CGRect

    /// Hard ceiling so a bogus preference / global frame can’t blow a tray piece up to full-screen.
    private var maxPlausibleCellSize: CGFloat {
        let w = UIScreen.main.bounds.width
        let perCell = (w - 40) / CGFloat(GameViewModel.boardSize)
        return min(110, max(36, perCell + 18))
    }

    /// Cell size for drag math + rendering while dragging.
    ///
    /// `BoardCellSizePreferenceKey` matches painted cells. `boardFrameInGlobal` can
    /// briefly disagree during layout (or report a bad width), which previously
    /// inflated `max(frame, pref)` and drew enormous “ghost” pieces over the grid.
    /// Prefer the preference whenever it looks sane; only blend in frame when it agrees.
    private var placementCellSize: CGFloat {
        let pref = boardCellSizeFromPreference
        let frameW = boardFrameInGlobal.width
        let fromFrame = cellSizeFromReportedGridWidth(frameW)
        let screenW = UIScreen.main.bounds.width
        let cap = maxPlausibleCellSize

        let frameWidthTrustworthy =
            boardFrameUsableForDragMath && frameW > 32 && frameW <= screenW * 1.08

        let raw: CGFloat
        if pref > 4 && pref <= cap {
            if fromFrame > 4, frameWidthTrustworthy {
                let ratio = fromFrame / pref
                if ratio >= 0.78 && ratio <= 1.22 {
                    raw = max(pref, fromFrame)
                } else {
                    raw = pref
                }
            } else {
                raw = pref
            }
        } else if fromFrame > 4, frameWidthTrustworthy, fromFrame <= cap {
            raw = fromFrame
        } else if pref > 4 {
            raw = min(pref, cap)
        } else {
            raw = min(max(28, pref), cap)
        }

        return min(max(raw, 18), cap)
    }

    private func cellSizeFromReportedGridWidth(_ w: CGFloat) -> CGFloat {
        let g = Board.gridSpacing
        let gapSpan = CGFloat(GameViewModel.boardSize - 1) * g
        guard w > gapSpan + 1 else { return 0 }
        return (w - gapSpan) / CGFloat(GameViewModel.boardSize)
    }

    private var trayCellSize: CGFloat {
        max(placementCellSize * 0.74, 18)
    }

    /// Scale applied so the piece **looks** grid-sized while dragging without
    /// swapping `shapeBody` to a huge intrinsic layout (that inflated the tray,
    /// painted outside the strip, and read as random blocks above the board).
    private var trayToPlacementVisualScale: CGFloat {
        let t = trayCellSize
        guard t > 1 else { return 1 }
        return placementCellSize / t
    }

    private var fingerLiftOffset: CGFloat { placementCellSize * 1.5 }

    /// Rejects stale or bogus rects (window-sized frames aren’t square; using them
    /// corrupts cell math and preview placement).
    private var isTrustworthyBoardFrame: Bool {
        let f = boardFrameInGlobal
        guard f.width > 40, f.height > 40 else { return false }
        let bounds = UIScreen.main.bounds
        guard f.width <= bounds.width * 1.1, f.height <= bounds.height * 1.1 else { return false }
        let d = abs(f.width - f.height)
        return d <= f.width * 0.15
    }

    /// The grid’s painted side length must match what `BoardCellSizePreferenceKey`
    /// implies; otherwise we can map a finger **over the tray** into “interior” coords
    /// on an oversized/wrong global rect → previews and drops jump to the middle.
    private var boardFrameMatchesPreferenceStride: Bool {
        guard isTrustworthyBoardFrame else { return false }
        let pref = boardCellSizeFromPreference
        guard pref > 4 else { return true }
        let f = boardFrameInGlobal
        let n = CGFloat(GameViewModel.boardSize)
        let g = Board.gridSpacing
        let expectedSide = n * pref + (n - 1) * g
        return abs(f.width - expectedSide) <= max(10, expectedSide * 0.075)
    }

    /// Single gate for converting global drag points into board space.
    private var boardFrameUsableForDragMath: Bool {
        boardFrameMatchesPreferenceStride
    }

    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false
    /// `DragGesture.Value.location` in `onEnded` can be wrong/intermittent; last `onChanged` is safer.
    @State private var lastDragGlobalLocation: CGPoint?

    var body: some View {
        shapeBody(cellSize: trayCellSize)
            .scaleEffect(isDragging ? trayToPlacementVisualScale : 0.95, anchor: .center)
            .opacity(isDragging ? 0.98 : 1.0)
            .offset(dragTranslation)
            // Don’t animate `isDragging`: scaling + offset together stay smooth; animating
            // the flag tended to hitch when preferences caught up mid-drag.
            .gesture(makeDragGesture())
            .modifier(TrayPieceIdentityObserver(pieceID: shape.id, reset: {
                viewModel.clearPreview()
                lastDragGlobalLocation = nil
                dragTranslation = .zero
                isDragging = false
            }))
            .disabled(viewModel.isGameOver)
            .onDisappear {
                // Always clear preview: gesture can end without `onEnded`, and `isDragging`
                // may already be false while `previewCells` still reflects this piece.
                viewModel.clearPreview()
                lastDragGlobalLocation = nil
                dragTranslation = .zero
                isDragging = false
            }
    }

    @ViewBuilder
    private func shapeBody(cellSize: CGFloat) -> some View {
        VStack(spacing: Board.gridSpacing) {
            ForEach(0..<shape.rows, id: \.self) { r in
                HStack(spacing: Board.gridSpacing) {
                    ForEach(0..<shape.cols, id: \.self) { c in
                        if shape.matrix[r][c] {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(shape.color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .frame(width: cellSize, height: cellSize)
                                .shadow(color: shape.color.opacity(0.4), radius: 2, y: 1)
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func makeDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging { isDragging = true }

                lastDragGlobalLocation = value.location

                dragTranslation = CGSize(
                    width: value.translation.width,
                    height: value.translation.height - fingerLiftOffset
                )

                guard let local = boardLocalPoint(fromGlobal: value.location) else {
                    viewModel.clearPreview()
                    return
                }
                updatePreview(for: local)
            }
            .onEnded { value in
                let endGlobal = lastDragGlobalLocation ?? value.location
                lastDragGlobalLocation = nil

                let placed: Bool
                if let local = boardLocalPoint(fromGlobal: endGlobal) {
                    placed = attemptPlacement(at: local)
                } else {
                    placed = false
                }

                // Always reset offset — on successful placement SwiftUI may reuse this
                // view for the next piece at the same tray index; leaving a non-zero
                // translation makes the new piece appear “floating” over the grid.
                if placed {
                    dragTranslation = .zero
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragTranslation = .zero
                    }
                }
                isDragging = false
                viewModel.clearPreview()
                viewModel.checkForGameOverAfterPlayerInteraction()
            }
    }

    private func boardLocalPoint(fromGlobal globalPoint: CGPoint) -> CGPoint? {
        guard boardFrameUsableForDragMath else { return nil }
        let frame = boardFrameInGlobal

        return CGPoint(
            x: globalPoint.x - frame.minX,
            y: globalPoint.y - frame.minY - fingerLiftOffset
        )
    }

    private func anchorCell(for point: CGPoint) -> (row: Int, col: Int)? {
        let cell = placementCellSize
        guard cell > 0 else { return nil }

        let g = Board.gridSpacing
        let stride = cell + g

        let shapeW = CGFloat(shape.cols) * cell + CGFloat(max(0, shape.cols - 1)) * g
        let shapeH = CGFloat(shape.rows) * cell + CGFloat(max(0, shape.rows - 1)) * g

        let topLeft = CGPoint(x: point.x - shapeW / 2, y: point.y - shapeH / 2)

        var col = Int(floor(topLeft.x / stride))
        var row = Int(floor(topLeft.y / stride))

        let rx = topLeft.x - CGFloat(col) * stride
        if rx > cell, col < GameViewModel.boardSize - 1 { col += 1 }

        let ry = topLeft.y - CGFloat(row) * stride
        if ry > cell, row < GameViewModel.boardSize - 1 { row += 1 }

        row = min(max(row, 0), GameViewModel.boardSize - shape.rows)
        col = min(max(col, 0), GameViewModel.boardSize - shape.cols)

        return (row, col)
    }

    private func updatePreview(for point: CGPoint) {
        guard let anchor = anchorCell(for: point) else {
            viewModel.clearPreview()
            return
        }
        viewModel.setPreview(shape: shape, originRow: anchor.row, originCol: anchor.col)
    }

    private func attemptPlacement(at point: CGPoint) -> Bool {
        guard let anchor = anchorCell(for: point) else { return false }
        return viewModel.place(trayIndex: trayIndex, atRow: anchor.row, col: anchor.col)
    }
}

// iOS 17+: two-parameter `onChange` (no deprecation). iOS 16: legacy API.
private struct TrayPieceIdentityObserver: ViewModifier {
    let pieceID: UUID
    let reset: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: pieceID) { _, _ in reset() }
        } else {
            content.onChange(of: pieceID) { _ in reset() }
        }
    }
}
