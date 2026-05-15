//
//  LeaderboardView.swift
//  BlockBlast
//
//  Second tab: editable player name + last 10 completed games (stored locally).
//

import SwiftUI

struct LeaderboardView: View {

    @ObservedObject private var firebase = FirebaseManager.shared
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Player name", text: $nameDraft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                    Button("Save name") {
                        firebase.setPlayerDisplayName(nameDraft)
                    }
                    .disabled(trimmed(nameDraft) == trimmed(firebase.playerDisplayName))
                } header: {
                    Text("Profile")
                } footer: {
                    Text("This name is saved on device and sent with each finished game.")
                        .font(.caption)
                }

                Section {
                    if firebase.recentPlayedGames.isEmpty {
                        Text("Finish a game to see your last scores here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(firebase.recentPlayedGames.enumerated()), id: \.element.id) { index, game in
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
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Your last 10 games")
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                nameDraft = firebase.playerDisplayName
            }
            .onChange(of: firebase.playerDisplayName) { _, new in
                nameDraft = new
            }
        }
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    LeaderboardView()
}
