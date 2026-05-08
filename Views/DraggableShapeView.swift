//
//  DraggableShapeView.swift
//  BlockBlast
//
//  Tray piece + drag gesture. Placement math uses:
//  • `DragGesture(coordinateSpace: .global)` — the tray is **not** under the
//    grid’s `.coordinateSpace`, so named-board-space drags are unreliable.
//  • `boardFrameInGlobal` — subtract from `location` to get grid-local points.
//  • Stride `cellSize + Board.gridSpacing` to match `LazyVGrid`.
//

import SwiftUI

struct DraggableShapeView: View {

    let trayIndex: Int
    let shape: BlockShape

    @ObservedObject var viewModel: GameViewModel

    @Environment(\.boardCellSize) private var boardCellSize: CGFloat
    @Environment(\.boardFrameInGlobal) private var boardFrameInGlobal: CGRect

    private var trayCellSize: CGFloat { max(boardCellSize * 0.7, 18) }

    /// Uses real cell size when known; otherwise tray size so lift isn’t 0.
    private var fingerLiftBase: CGFloat {
        boardCellSize > 0 ? boardCellSize : trayCellSize
    }

    private var fingerLiftOffset: CGFloat { fingerLiftBase * 1.5 }

    /// Avoid a 0×0 drag preview before `boardCellSize` preference arrives.
    private var renderCellSizeWhileDragging: CGFloat {
        boardCellSize > 0 ? boardCellSize : trayCellSize
    }

    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        let activeCellSize = isDragging ? renderCellSizeWhileDragging : trayCellSize

        shapeBody(cellSize: activeCellSize)
            .opacity(isDragging ? 0.95 : 1.0)
            .offset(dragTranslation)
            .scaleEffect(isDragging ? 1.0 : 0.95)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
            .gesture(makeDragGesture())
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

                if !placed {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragTranslation = .zero
                    }
                }
                isDragging = false
                viewModel.clearPreview()
            }
    }

    /// Converts global finger position to coordinates inside the LazyVGrid rect.
    private func boardLocalPoint(fromGlobal globalPoint: CGPoint) -> CGPoint? {
        let frame = boardFrameInGlobal
        guard frame.width > 1, frame.height > 1 else { return nil }

        return CGPoint(
            x: globalPoint.x - frame.minX,
            y: globalPoint.y - frame.minY - fingerLiftOffset
        )
    }

    private func anchorCell(for point: CGPoint) -> (row: Int, col: Int)? {
        guard boardCellSize > 0 else { return nil }

        let g = Board.gridSpacing
        let stride = boardCellSize + g

        let shapeW = CGFloat(shape.cols) * boardCellSize + CGFloat(max(0, shape.cols - 1)) * g
        let shapeH = CGFloat(shape.rows) * boardCellSize + CGFloat(max(0, shape.rows - 1)) * g

        let topLeft = CGPoint(x: point.x - shapeW / 2, y: point.y - shapeH / 2)

        var col = Int(floor(topLeft.x / stride))
        var row = Int(floor(topLeft.y / stride))

        let rx = topLeft.x - CGFloat(col) * stride
        if rx > boardCellSize, col < GameViewModel.boardSize - 1 { col += 1 }

        let ry = topLeft.y - CGFloat(row) * stride
        if ry > boardCellSize, row < GameViewModel.boardSize - 1 { row += 1 }

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
