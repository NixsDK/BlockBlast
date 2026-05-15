//
//  LeaderboardView.swift
//  BlockBlast
//
//  Second tab: editable player name + last 10 completed games (stored locally).
//
//  Keep the player-name `TextField` **outside** `List`: list row recycling +
//  `@ObservedObject` updates can reset `@State` on the field (classic “only one
//  letter” / stuck character bugs).
//

import SwiftUI

struct LeaderboardView: View {

    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var nameDraft = ""

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
                nameDraft = firebase.playerDisplayName
            }
        }
    }

    private var profileBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)

            TextField("Player name", text: $nameDraft)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.18))
                )
                .foregroundStyle(.primary)

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

#Preview {
    LeaderboardView()
}
