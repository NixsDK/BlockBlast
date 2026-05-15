//
//  LeaderboardView.swift
//  BlockBlast
//
//  Second tab: editable player name + last 10 completed games (stored locally).
//
//  Avoid SwiftUI `TextField` inside recycled containers for the name field.
//  Also guard against `onAppear` running more than once per tab “session” so a
//  Firebase `@ObservedObject` refresh cannot keep resetting `nameDraft` (often
//  reads as “every key becomes A” when `playerDisplayName` was saved as “A”).
//

import SwiftUI
import UIKit

struct LeaderboardView: View {

    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var nameDraft = ""
    /// Prevents re-seeding `nameDraft` from Firebase if `onAppear` fires again while this tab stays visible.
    @State private var didSeedNameDraftForSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    profileBlock

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your last 10 games")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if firebase.recentPlayedGames.isEmpty {
                            Text("Finish a game to see your last scores here.")
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(firebase.recentPlayedGames.enumerated()), id: \.element.id) { index, game in
                                    gameRow(index: index, game: game)
                                    if index < firebase.recentPlayedGames.count - 1 {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(white: 0.14))
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(red: 0.06, green: 0.06, blue: 0.09))
            .onAppear {
                guard !didSeedNameDraftForSession else { return }
                didSeedNameDraftForSession = true
                nameDraft = firebase.playerDisplayName
            }
            .onDisappear {
                didSeedNameDraftForSession = false
            }
        }
    }

    private var profileBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)

            PlayerNameTextField(text: $nameDraft)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.18))
                )

            Button("Save name") {
                firebase.setPlayerDisplayName(nameDraft)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmed(nameDraft) == trimmed(firebase.playerDisplayName))

            Text("This name is saved on device and sent with each finished game.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.12))
        )
    }

    private func gameRow(index: Int, game: LeaderboardEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("#\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(game.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(game.score)")
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - UIKit field (avoids SwiftUI TextField quirks + fights less with ObservableObject redraws)

private struct PlayerNameTextField: UIViewRepresentable {

    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = "Player name"
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .words
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.textContentType = .nickname
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.textColor = .white
        tf.tintColor = .systemYellow
        tf.font = .preferredFont(forTextStyle: .body)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        tf.accessibilityLabel = "Player name"
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        guard uiView.text != text else { return }
        if uiView.isFirstResponder == false {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PlayerNameTextField

        init(_ parent: PlayerNameTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

#Preview {
    LeaderboardView()
}
