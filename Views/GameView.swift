//
//  GameView.swift
//  BlockBlast
//
//  Top-level screen. Composes the score header, the 8x8 board, the tray of
//  three draggable shapes, and the two Lottie overlays (combo + game over).
//
//  Architectural note: GameView owns the GameViewModel as @StateObject. All
//  child views observe the same instance so that drag interactions in one
//  subtree update the board in another without prop-drilling.
//

import SwiftUI

struct GameView: View {

    @StateObject private var viewModel = GameViewModel()
    @ObservedObject private var firebase = FirebaseManager.shared

    /// Filled from `BoardView` via `PreferenceKey` so tray `DraggableShapeView`s
    /// see the same cell size as the grid (they are not inside `BoardView`).
    @State private var boardCellSize: CGFloat = 0

    /// Grid frame in window/global coords — paired with `.global` `DragGesture`.
    @State private var boardFrameInGlobal: CGRect = .zero

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                BoardView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                trayView
                    .frame(height: 130)
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .onPreferenceChange(BoardCellSizePreferenceKey.self) { boardCellSize = $0 }
            .onPreferenceChange(BoardFramePreferenceKey.self) { boardFrameInGlobal = $0 }
            .environment(\.boardCellSize, boardCellSize)
            .environment(\.boardFrameInGlobal, boardFrameInGlobal)

            // Combo confetti — fires when the player clears 3+ lines at once.
            // The opacity trick lets the same view stay mounted (preserving
            // Lottie state) while only being visible during the burst.
            comboOverlay
                .allowsHitTesting(false)

            // Game-over overlay
            if viewModel.isGameOver {
                gameOverOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isGameOver)
    }

    // MARK: - Header (score + combo + personal best)

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(viewModel.score)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(viewModel.score)))
                    .animation(.spring(response: 0.3), value: viewModel.score)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(firebase.personalBest)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                if viewModel.comboStreak > 1 {
                    Text("Combo x\(viewModel.comboStreak)")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Tray (3 draggable shapes)

    private var trayView: some View {
        HStack(spacing: 12) {
            ForEach(0..<GameViewModel.trayCapacity, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))

                    if let shape = viewModel.tray[index] {
                        DraggableShapeView(
                            trayIndex: index,
                            shape: shape,
                            viewModel: viewModel
                        )
                        // Fresh drag state per spawned piece; avoids reused @State when the tray refills.
                        .id(shape.id)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Combo overlay (Lottie)

    private var comboOverlay: some View {
        // Visible only while the most recent clear was a "big" combo.
        // Auto-hides as the playToken increment finishes its single play.
        LottieView(
            animationName: "combo",
            loopMode: .playOnce,
            playToken: viewModel.comboBurstToken
        )
        .opacity(viewModel.lastClearCount >= GameViewModel.bigComboThreshold ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.comboBurstToken)
    }

    // MARK: - Game over overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                LottieView(
                    animationName: "gameover",
                    loopMode: .loop,
                    playToken: viewModel.gameOverBurstToken
                )
                .frame(width: 220, height: 220)

                Text("Game Over")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text("Final Score")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(viewModel.score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }

                if viewModel.newPersonalBestThisGame {
                    Text("New Personal Best!")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.top, 4)
                }

                Button {
                    viewModel.restart()
                } label: {
                    Text("Play Again")
                        .font(.headline.bold())
                        .frame(maxWidth: 220)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.07, blue: 0.12),
                     Color(red: 0.02, green: 0.02, blue: 0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    GameView()
}
