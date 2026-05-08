//
//  BlockShape.swift
//  BlockBlast
//
//  A polyomino piece that the player drags onto the board. Each shape is
//  expressed as a small dense matrix of bools where `true` means "this cell
//  is part of the piece". Sizes range from 1x1 (a single tile) up to 3x3
//  (an L-tromino, square, T-piece, etc.) — exactly the vocabulary used by
//  classic "Block Blast"-style games.
//

import SwiftUI

struct BlockShape: Identifiable, Equatable {

    /// Stable id so SwiftUI can diff the tray correctly across refills.
    let id: UUID
    /// Dense matrix: `matrix[row][col] == true` means the cell is filled.
    let matrix: [[Bool]]
    /// The colour painted into every filled cell of the placed piece.
    let color: Color

    init(id: UUID = UUID(), matrix: [[Bool]], color: Color) {
        self.id = id
        self.matrix = matrix
        self.color = color
    }

    // MARK: - Derived geometry

    var rows: Int { matrix.count }
    var cols: Int { matrix.first?.count ?? 0 }

    /// All `(row, col)` offsets that are "on" inside the matrix. Useful for
    /// collision checks and for rendering only the filled cells.
    var filledOffsets: [(row: Int, col: Int)] {
        var result: [(Int, Int)] = []
        result.reserveCapacity(rows * cols)
        for r in 0..<rows {
            for c in 0..<cols where matrix[r][c] {
                result.append((r, c))
            }
        }
        return result
    }

    /// Number of filled cells — also the score awarded for placement.
    var cellCount: Int { filledOffsets.count }

    static func == (lhs: BlockShape, rhs: BlockShape) -> Bool { lhs.id == rhs.id }
}

// MARK: - Catalog

extension BlockShape {

    /// The full library of pieces the game can spawn. Colours are tuned to
    /// remain readable on both light and dark board cells.
    static let catalog: [BlockShape] = [

        // Singleton
        BlockShape(matrix: [[true]], color: .yellow),

        // Dominoes
        BlockShape(matrix: [[true, true]], color: .orange),
        BlockShape(matrix: [[true], [true]], color: .orange),

        // Triominoes (I)
        BlockShape(matrix: [[true, true, true]], color: .red),
        BlockShape(matrix: [[true], [true], [true]], color: .red),

        // Tetrominoes (I)
        BlockShape(matrix: [[true, true, true, true]], color: .pink),
        BlockShape(matrix: [[true], [true], [true], [true]], color: .pink),

        // Pentomino (I) — long bar that often forces clears
        BlockShape(matrix: [[true, true, true, true, true]], color: .purple),
        BlockShape(matrix: [[true], [true], [true], [true], [true]], color: .purple),

        // 2x2 square
        BlockShape(matrix: [
            [true, true],
            [true, true]
        ], color: .blue),

        // 3x3 square (the dreaded big block)
        BlockShape(matrix: [
            [true, true, true],
            [true, true, true],
            [true, true, true]
        ], color: .indigo),

        // L-shapes (all 4 rotations)
        BlockShape(matrix: [
            [true, false],
            [true, false],
            [true, true]
        ], color: .green),
        BlockShape(matrix: [
            [true, true, true],
            [true, false, false]
        ], color: .green),
        BlockShape(matrix: [
            [true, true],
            [false, true],
            [false, true]
        ], color: .green),
        BlockShape(matrix: [
            [false, false, true],
            [true,  true,  true]
        ], color: .green),

        // J-shapes (all 4 rotations)
        BlockShape(matrix: [
            [false, true],
            [false, true],
            [true,  true]
        ], color: .teal),
        BlockShape(matrix: [
            [true,  false, false],
            [true,  true,  true]
        ], color: .teal),
        BlockShape(matrix: [
            [true,  true],
            [true,  false],
            [true,  false]
        ], color: .teal),
        BlockShape(matrix: [
            [true,  true,  true],
            [false, false, true]
        ], color: .teal),

        // T-shapes
        BlockShape(matrix: [
            [true, true, true],
            [false, true, false]
        ], color: .mint),
        BlockShape(matrix: [
            [false, true, false],
            [true,  true, true]
        ], color: .mint),

        // S/Z shapes
        BlockShape(matrix: [
            [false, true, true],
            [true,  true, false]
        ], color: .cyan),
        BlockShape(matrix: [
            [true,  true, false],
            [false, true, true]
        ], color: .cyan),

        // Diagonals — distinctive "Block Blast" shapes
        BlockShape(matrix: [
            [true,  false],
            [false, true]
        ], color: .brown),
        BlockShape(matrix: [
            [true,  false, false],
            [false, true,  false],
            [false, false, true]
        ], color: .brown),
    ]

    /// Returns a brand-new shape (fresh `id`) drawn uniformly from the catalog.
    static func random() -> BlockShape {
        let template = catalog.randomElement()!
        return BlockShape(matrix: template.matrix, color: template.color)
    }
}
