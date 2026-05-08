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

struct DraggableShapeView: View {

    let trayIndex: Int
    let shape: BlockShape

    @ObservedObject var viewModel: GameViewModel

    @Environment(\.boardCellSize) private var boardCellSizeFromPreference: CGFloat
    @Environment(\.boardFrameInGlobal) private var boardFrameInGlobal: CGRect

    /// Matches BoardView: `(gridWidth − (n−1)·g) / n`.
    private var placementCellSize: CGFloat {
        let g = Board.gridSpacing
        let n = CGFloat(GameViewModel.boardSize)
        let gapSpan = CGFloat(GameViewModel.boardSize - 1) * g
        let w = boardFrameInGlobal.width
        let fromFrame = (w > gapSpan + 1) ? (w - gapSpan) / n : 0
        let merged = max(fromFrame, boardCellSizeFromPreference)
        if merged > 1 { return merged }
        return max(28, boardCellSizeFromPreference)
    }

    private var trayCellSize: CGFloat {
        max(placementCellSize * 0.74, 18)
    }

    private var fingerLiftOffset: CGFloat { placementCellSize * 1.5 }

    /// Subtle lift while dragging (cell size already matches the grid).
    private let dragVisualScale: CGFloat = 1.03

    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        shapeBody(cellSize: isDragging ? placementCellSize : trayCellSize)
            .scaleEffect(isDragging ? dragVisualScale : 0.95)
            .opacity(isDragging ? 0.98 : 1.0)
            .offset(dragTranslation)
            // Don’t animate `isDragging`: it swaps tray vs board cell sizes and can
            // ripple layout/preference updates so the whole board briefly rescales.
            .gesture(makeDragGesture())
            .onChange(of: shape.id) { _ in
                dragTranslation = .zero
                isDragging = false
            }
            .disabled(viewModel.isGameOver)
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
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                if !isDragging { isDragging = true }

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
                let placed: Bool
                if let local = boardLocalPoint(fromGlobal: value.location) {
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
        let frame = boardFrameInGlobal
        guard frame.width > 1, frame.height > 1 else { return nil }

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
