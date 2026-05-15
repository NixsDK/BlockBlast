//
//  FirebaseManager.swift
//  BlockBlast
//
//  Thin singleton that owns the two Firebase responsibilities the game cares
//  about:
//    1. Anonymous authentication on first launch (stable `uid`).
//    2. Writing completed-game rows to the global `Leaderboard` collection.
//
//  Personal-best + last-10-games history are mirrored locally so the leaderboard
//  tab works offline and isn’t blocked on the network.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

private struct PersistedPlayedGame: Codable {
    let id: String
    let userId: String
    let displayName: String
    let score: Int
    let createdAt: Date
}

@MainActor
final class FirebaseManager: ObservableObject {

    static let shared = FirebaseManager()

    // MARK: - Published state (driven into the UI)

    @Published private(set) var currentUserId: String?
    @Published private(set) var personalBest: Int
    /// Trimmed name entered on the Leaderboard tab (persisted in UserDefaults).
    @Published private(set) var playerDisplayName: String = ""
    /// Newest-first; capped at 10 entries; persisted locally.
    @Published private(set) var recentPlayedGames: [LeaderboardEntry] = []

    // MARK: - Internals

    private let db = Firestore.firestore()
    private let leaderboardCollection = "Leaderboard"
    private let personalBestKey = "BlockBlast.personalBest"
    private let playerDisplayNameKey = "BlockBlast.playerDisplayName"
    private static let recentPlayedGamesStorageKey = "BlockBlast.recentPlayedGames"

    private init() {
        self.personalBest = UserDefaults.standard.integer(forKey: personalBestKey)
        self.currentUserId = Auth.auth().currentUser?.uid
        self.playerDisplayName = UserDefaults.standard.string(forKey: playerDisplayNameKey) ?? ""
        self.recentPlayedGames = Self.loadRecentPlayedGamesFromStorage()
    }

    // MARK: - Authentication

    /// Signs the user in anonymously if they're not already authenticated.
    func signInAnonymouslyIfNeeded() async {
        if let existing = Auth.auth().currentUser {
            self.currentUserId = existing.uid
            return
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.currentUserId = result.user.uid
        } catch {
            print("[FirebaseManager] Anonymous sign-in failed: \(error)")
        }
    }

    // MARK: - Player name

    func setPlayerDisplayName(_ raw: String) {
        let trimmed = String(raw.prefix(24)).trimmingCharacters(in: .whitespacesAndNewlines)
        playerDisplayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: playerDisplayNameKey)
    }

    private func effectiveLeaderboardDisplayName() -> String {
        let t = playerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        if let uid = currentUserId ?? Auth.auth().currentUser?.uid {
            return "Player-\(uid.prefix(4))"
        }
        return "Player"
    }

    // MARK: - Personal best + game history

    @discardableResult
    func updatePersonalBestIfNeeded(_ score: Int) -> Bool {
        guard score > personalBest else { return false }
        personalBest = score
        UserDefaults.standard.set(score, forKey: personalBestKey)
        return true
    }

    /// Call once when a game ends: updates local history (always) and queues Firestore write (when signed in).
    func recordGameCompletion(score: Int) {
        let uid = currentUserId ?? Auth.auth().currentUser?.uid ?? ""
        let snapshotName = effectiveLeaderboardDisplayName()
        let entry = LeaderboardEntry(
            id: UUID().uuidString,
            userId: uid,
            displayName: snapshotName,
            score: score,
            createdAt: Date()
        )
        var next = recentPlayedGames
        next.insert(entry, at: 0)
        if next.count > 10 { next = Array(next.prefix(10)) }
        recentPlayedGames = next
        persistRecentPlayedGames()

        Task { await writeLeaderboardEntry(score: score) }
    }

    private static func loadRecentPlayedGamesFromStorage() -> [LeaderboardEntry] {
        guard let data = UserDefaults.standard.data(forKey: Self.recentPlayedGamesStorageKey),
              let decoded = try? JSONDecoder().decode([PersistedPlayedGame].self, from: data) else {
            return []
        }
        return decoded.map {
            LeaderboardEntry(id: $0.id, userId: $0.userId, displayName: $0.displayName, score: $0.score, createdAt: $0.createdAt)
        }
    }

    private func persistRecentPlayedGames() {
        let persisted = recentPlayedGames.map {
            PersistedPlayedGame(id: $0.id, userId: $0.userId, displayName: $0.displayName, score: $0.score, createdAt: $0.createdAt)
        }
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: Self.recentPlayedGamesStorageKey)
        }
    }

    // MARK: - Firestore

    private func writeLeaderboardEntry(score: Int) async {
        guard let uid = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("[FirebaseManager] Cannot write score — no authenticated user")
            return
        }

        let payload: [String: Any] = [
            "userId": uid,
            "displayName": effectiveLeaderboardDisplayName(),
            "score": score,
            "createdAt": Timestamp(date: Date()),
        ]

        db.collection(leaderboardCollection).addDocument(data: payload) { error in
            if let error {
                print("[FirebaseManager] Failed to write leaderboard entry: \(error)")
            }
        }
    }
}
