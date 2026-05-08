//
//  DraggableShapeView.swift
//  BlockBlast
//
//  Visual representation of a single tray piece. Owns the DragGesture that
//  lets the user pick up the piece and drop it onto the board.
//
//  How the coordinate math works:
//   • While idle the piece renders at "tray scale" (smaller than a board cell)
//     so all three pieces fit comfortably below the grid.
//   • On drag start we scale the piece up to the board cell size so the
//     preview matches what would be placed.
//   • The DragGesture reports its `location` in two coordinate spaces:
//       1. `Board.coordinateSpace`   – used to compute (row, col)
//       2. `.global`                 – used to translate the floating preview
//          to follow the finger.
//   • An additional vertical "lift" offset displays the piece above the
//     finger so the player can actually see what they're placing.
//

import SwiftUI

struct DraggableShapeView: View {

    let trayIndex: Int
    let shape: BlockShape

    /// View-model is observed so that when the piece is consumed and
    /// the parent removes us from the layout, the binding is clean.
    @ObservedObject var viewModel: GameViewModel

    /// Cell size on the board, supplied via Environment by `BoardView`.
    @Environment(\.boardCellSize) private var boardCellSize: CGFloat

    /// Tray cell size — purely cosmetic; ~70% of board size feels right.
    private var trayCellSize: CGFloat { max(boardCellSize * 0.7, 18) }

    /// Lift the piece above the finger by ~1.5 cells so the user can see the
    /// preview cells under it. Tuned by feel, mirrors the iOS Block Blast UX.
    private var fingerLiftOffset: CGFloat { boardCellSize * 1.5 }

    /// Drag state.
    @State private var dragTranslation: CGSize = .zero
    @State private var dragLocationInBoard: CGPoint? = nil
    @State private var isDragging: Bool = false

    var body: some View {
        let activeCellSize = isDragging ? boardCellSize : trayCellSize

        shapeBody(cellSize: activeCellSize)
            .opacity(isDragging ? 0.95 : 1.0)
            .offset(dragTranslation)
            // Slight bounce when the player picks the piece up.
            .scaleEffect(isDragging ? 1.0 : 0.95)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
            .gesture(makeDragGesture())
    }

    // MARK: - Visual

    @ViewBuilder
    private func shapeBody(cellSize: CGFloat) -> some View {
        VStack(spacing: 2) {
            ForEach(0..<shape.rows, id: \.self) { r in
                HStack(spacing: 2) {
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
                            // Transparent spacer keeps the matrix layout
                            // square even with non-rectangular shapes.
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Drag

    private func makeDragGesture() -> some Gesture {
        DragGesture(coordinateSpace: .named(Board.coordinateSpace))
            .onChanged { value in
                if !isDragging { isDragging = true }

                // 1. Move the floating preview with the finger. We use
                //    `translation` so the piece tracks 1:1 with the gesture
                //    regardless of tray placement.
                dragTranslation = CGSize(
                    width: value.translation.width,
                    height: value.translation.height - fingerLiftOffset
                )

                // 2. Compute the cell under the (lifted) anchor and ask the
                //    view-model to highlight a preview if valid.
                let pointInBoard = CGPoint(
                    x: value.location.x,
                    y: value.location.y - fingerLiftOffset
                )
                dragLocationInBoard = pointInBoard
                updatePreview(for: pointInBoard)
            }
            .onEnded { value in
                let pointInBoard = CGPoint(
                    x: value.location.x,
                    y: value.location.y - fingerLiftOffset
                )
                let placed = attemptPlacement(at: pointInBoard)

                if !placed {
                    // Snap back to the tray with a little bounce.
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragTranslation = .zero
                    }
                }
                isDragging = false
                dragLocationInBoard = nil
                viewModel.clearPreview()
            }
    }

    // MARK: - Coordinate math

    /// Converts a board-space point to the `(row, col)` of the shape's
    /// top-left anchor. The anchor is offset by half the shape's bounding
    /// box so the piece feels centred on the finger.
    private func anchorCell(for point: CGPoint) -> (row: Int, col: Int)? {
        guard boardCellSize > 0 else { return nil }

        // Adjust the point so it represents the *top-left* cell of the shape
        // rather than the centre. This matches the visual placement and
        // makes the preview line up exactly with the dropped piece.
        let halfWidth  = CGFloat(shape.cols) * boardCellSize / 2
        let halfHeight = CGFloat(shape.rows) * boardCellSize / 2

        let adjusted = CGPoint(
            x: point.x - halfWidth + boardCellSize / 2,
            y: point.y - halfHeight + boardCellSize / 2
        )

        // 2pt of inter-cell padding is part of the LazyVGrid; we treat each
        // (cell + spacing) as one stride. Using the cell size alone is close
        // enough at our resolutions and avoids fiddly corner cases.
        let row = Int(floor(adjusted.y / boardCellSize))
        let col = Int(floor(adjusted.x / boardCellSize))
        return (row, col)
    }

    private func updatePreview(for point: CGPoint) {
        guard let anchor = anchorCell(for: point) else {
            viewModel.clearPreview()
            return
        }
        viewModel.setPreview(shape: shape, originRow: anchor.row, originCol: anchor.col)
    }

    /// Attempts to commit placement at the current drag location. Returns
    /// true if the placement succeeded (so the view doesn't snap back).
    private func attemptPlacement(at point: CGPoint) -> Bool {
        guard let anchor = anchorCell(for: point) else { return false }
        return viewModel.place(trayIndex: trayIndex, atRow: anchor.row, col: anchor.col)
    }
}
