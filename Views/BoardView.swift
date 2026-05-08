//
//  BoardView.swift
//  BlockBlast
//
//  The 8x8 game board, rendered with `LazyVGrid` per the project brief.
//
//  The view exposes its frame via the named coordinate space `Board.coordinateSpace`,
//  which the draggable pieces read to translate finger positions into grid
//  indices. Cell size is derived from the available width so the board scales
//  cleanly across iPhone sizes.
//

import SwiftUI

enum Board {
    /// Named coordinate space used by `DraggableShapeView` to compute
    /// `(row, col)` from a global drag location.
    static let coordinateSpace = "Board"
}

struct BoardView: View {

    @ObservedObject var viewModel: GameViewModel

    /// The columns spec — strict 8 columns of equal width with no spacing.
    /// The cell size is derived from the rendered frame to stay pixel-perfect.
    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: GameViewModel.boardSize
    )

    var body: some View {
        GeometryReader { geo in
            // Cell size: total width minus the inter-cell gaps, divided evenly.
            let totalSpacing = CGFloat(GameViewModel.boardSize - 1) * 2
            let cellSize = (geo.size.width - totalSpacing) / CGFloat(GameViewModel.boardSize)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.grid.flatMap { $0 }) { cell in
                    cellView(for: cell, size: cellSize)
                }
            }
            // The named coordinate space lets DragGesture report locations
            // relative to the board's origin — much simpler math than going
            // through .global and then doing the conversion ourselves.
            .coordinateSpace(name: Board.coordinateSpace)
            // Square the board: width == height.
            .frame(width: geo.size.width, height: geo.size.width)
            // Expose the cell size to the environment so DraggableShapeView
            // can read it without prop-drilling.
            .environment(\.boardCellSize, cellSize)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.12))
        )
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
            .animation(.easeOut(duration: 0.15), value: cell.color)
    }

    private func isInPreview(_ cell: GridCell) -> Bool {
        viewModel.previewCells.contains { $0.row == cell.row && $0.col == cell.col }
    }

    private func fillColor(for cell: GridCell, preview: Bool) -> Color {
        if let placed = cell.color { return placed }
        if preview, let pColor = viewModel.previewColor { return pColor.opacity(0.45) }
        // Subtle empty-cell colour with a checker pattern so the player can
        // count cells visually.
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

// MARK: - Environment plumbing for cell size

private struct BoardCellSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// The current board cell size in points. Read by `DraggableShapeView`
    /// so the dragged piece is scaled to match the board exactly.
    var boardCellSize: CGFloat {
        get { self[BoardCellSizeKey.self] }
        set { self[BoardCellSizeKey.self] = newValue }
    }
}
