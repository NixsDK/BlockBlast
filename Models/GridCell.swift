//
//  GridCell.swift
//  BlockBlast
//
//  A single cell on the 8x8 board. Cells are value types so that the
//  `GameViewModel` can publish a mutated copy of its grid and SwiftUI's diff
//  engine will redraw only the changed cells.
//

import SwiftUI

struct GridCell: Identifiable, Equatable {
    /// Stable identity for SwiftUI; the row*8+col packing keeps it cheap.
    let id: Int
    let row: Int
    let col: Int
    /// `nil` when the cell is empty. When non-nil, the cell is filled and
    /// renders with this colour.
    var color: Color?

    init(row: Int, col: Int, color: Color? = nil) {
        self.row = row
        self.col = col
        self.id = row * GridCell.boardSize + col
        self.color = color
    }

    var isEmpty: Bool { color == nil }
    var isFilled: Bool { color != nil }

    /// The board is a strict 8x8. Centralising the constant here lets the
    /// view-model, board view, and drag math share a single source of truth.
    static let boardSize = 8
}
