//
//  BoardView.swift
//  BlockBlast
//
//  The 8x8 game board, rendered with `LazyVGrid` per the project brief.
//
//  When `gridInnerDimension` is set by `GameView`, the grid stays that exact
//  square size so tray drags / header tweaks don’t change the proposal and
//  cause visible “zoom” rescaling.
//

import SwiftUI

enum Board {
    /// Named coordinate space used by `DraggableShapeView` to compute
    /// `(row, col)` from a global drag location.
    static let coordinateSpace = "Board"

    /// Must stay in sync with `LazyVGrid` / `GridItem` spacing below — drag
    /// math in `DraggableShapeView` relies on the same stride.
    static let gridSpacing: CGFloat = 2
}

/// Bubbles the live board cell size up to `GameView` so tray pieces (siblings
/// of `BoardView`, not descendants of the grid) receive `@Environment(\.boardCellSize)`.
struct BoardCellSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// `LazyVGrid` bounds in global coordinates — tray drags convert `.global` → grid.
struct BoardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let n = nextValue()
        if n.width > 0, n.height > 0 { value = n }
    }
}

struct BoardView: View {

    @ObservedObject var viewModel: GameViewModel

    /// Pixel width/height of the 8×8 grid **inside** the 8pt chrome padding.
    /// `nil` → fall back to flexible `GeometryReader` + aspect ratio (previews only).
    var gridInnerDimension: CGFloat? = nil

    /// The columns spec — strict 8 columns of equal width with no spacing.
    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: Board.gridSpacing),
        count: GameViewModel.boardSize
    )

    var body: some View {
        Group {
            if let dim = gridInnerDimension, dim > 32 {
                chromeWrapped(gridContent(side: dim))
            } else {
                GeometryReader { geo in
                    let s = min(geo.size.width, geo.size.height)
                    gridContent(side: s)
                }
                .aspectRatio(1, contentMode: .fit)
                .modifier(ChromeWrap())
            }
        }
    }

    private func chromeWrapped(_ grid: some View) -> some View {
        grid
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.12))
            )
    }

    @ViewBuilder
    private func gridContent(side: CGFloat) -> some View {
        let totalSpacing = CGFloat(GameViewModel.boardSize - 1) * Board.gridSpacing
        let cellSize = (side - totalSpacing) / CGFloat(GameViewModel.boardSize)

        LazyVGrid(columns: columns, spacing: Board.gridSpacing) {
            ForEach(viewModel.grid.flatMap { $0 }) { cell in
                cellView(for: cell, size: cellSize)
            }
        }
        .transaction { $0.animation = nil }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BoardFramePreferenceKey.self,
                    value: proxy.frame(in: .global)
                )
            }
        )
        .coordinateSpace(name: Board.coordinateSpace)
        .frame(width: side, height: side)
        .environment(\.boardCellSize, cellSize)
        .preference(key: BoardCellSizePreferenceKey.self, value: cellSize)
    }

    // MARK: - Cell rendering

    @ViewBuilder
    private func cellView(for cell: GridCell, size: CGFloat) -> some View {
        let preview = isInPreview(cell)
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fillColor(for: cell, preview: preview))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(strokeColor(for: cell, preview: preview), lineWidth: 1)
            )
            .frame(width: size, height: size)
    }

    private func isInPreview(_ cell: GridCell) -> Bool {
        viewModel.previewCells.contains { $0.row == cell.row && $0.col == cell.col }
    }

    private func fillColor(for cell: GridCell, preview: Bool) -> Color {
        if let placed = cell.color { return placed }
        if preview, let pColor = viewModel.previewColor { return pColor.opacity(0.45) }
        return ((cell.row + cell.col).isMultiple(of: 2))
            ? Color(white: 0.18)
            : Color(white: 0.22)
    }

    private func strokeColor(for cell: GridCell, preview: Bool) -> Color {
        if cell.color != nil { return Color.white.opacity(0.18) }
        if preview { return Color.white.opacity(0.5) }
        return Color.white.opacity(0.05)
    }
}

private struct ChromeWrap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.12))
            )
    }
}

// MARK: - Environment plumbing for drag / layout

private struct BoardCellSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct BoardFrameKey: EnvironmentKey {
    static var defaultValue: CGRect = .zero
}

extension EnvironmentValues {
    var boardCellSize: CGFloat {
        get { self[BoardCellSizeKey.self] }
        set { self[BoardCellSizeKey.self] = newValue }
    }

    var boardFrameInGlobal: CGRect {
        get { self[BoardFrameKey.self] }
        set { self[BoardFrameKey.self] = newValue }
    }
}
