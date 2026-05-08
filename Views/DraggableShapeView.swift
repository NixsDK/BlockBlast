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

    /// Cell size for drag math + rendering while dragging.
    ///
    /// `BoardCellSizePreferenceKey` matches painted cells. `boardFrameInGlobal` can
    /// briefly disagree during layout (or report a bad width), which previously
    /// inflated `max(frame, pref)` and drew enormous “ghost” pieces over the grid.
    /// Prefer the preference whenever it looks sane; only blend in frame when it agrees.
    private var placementCellSize: CGFloat {
        let pref = boardCellSizeFromPreference
        let fromFrame = cellSizeFromReportedGridWidth(boardFrameInGlobal.width)

        if pref > 4 {
            if fromFrame > 4 {
                let ratio = fromFrame / pref
                if ratio >= 0.78 && ratio <= 1.22 {
                    return max(pref, fromFrame)
                }
            }
            return pref
        }

        if fromFrame > 4 { return fromFrame }
        return max(28, pref)
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

    private var fingerLiftOffset: CGFloat { placementCellSize * 1.5 }

    /// Match grid scale exactly while dragging (extra scale looked like “zoom”).
    private let dragVisualScale: CGFloat = 1.0

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
            .onDisappear {
                // Gesture can cancel without `onEnded`; don’t leave preview/offset stuck.
                if isDragging { viewModel.clearPreview() }
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
