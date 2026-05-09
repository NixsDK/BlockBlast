//
//  FirebaseManager.swift
//  BlockBlast
//
//  Thin singleton that owns the two Firebase responsibilities the game cares
//  about:
//    1. Anonymous authentication on first launch (so every player has a
//       stable `uid` we can attribute scores to).
//    2. Reading and writing the global `Leaderboard` collection.
//
//  Personal-best tracking is mirrored to UserDefaults so we can short-circuit
//  the Firestore write when the new score doesn't beat the local record.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseManager: ObservableObject {

    static let shared = FirebaseManager()

    // MARK: - Published state (driven into the UI)

    @Published private(set) var currentUserId: String?
    @Published private(set) var personalBest: Int
    @Published private(set) var topEntries: [LeaderboardEntry] = []

    // MARK: - Internals

    private let db = Firestore.firestore()
    private let leaderboardCollection = "Leaderboard"
    private let personalBestKey = "BlockBlast.personalBest"

    private init() {
        self.personalBest = UserDefaults.standard.integer(forKey: personalBestKey)
        self.currentUserId = Auth.auth().currentUser?.uid
    }

    // MARK: - Authentication

    /// Signs the user in anonymously if they're not already authenticated.
    /// Safe to call repeatedly (e.g. from `.task` on the root view) — it
    /// short-circuits if `Auth.auth().currentUser` already exists.
    func signInAnonymouslyIfNeeded() async {
        if let existing = Auth.auth().currentUser {
            self.currentUserId = existing.uid
            return
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.currentUserId = result.user.uid
        } catch {
            // We deliberately swallow the error here — the game is fully
            // playable offline, leaderboard writes simply won't happen.
            print("[FirebaseManager] Anonymous sign-in failed: \(error)")
        }
    }

    // MARK: - Personal best + Leaderboard

    /// Returns `true` and persists if the supplied score beats the local
    /// personal best. The Firestore write is fired-and-forgotten because UI
    /// flow shouldn't block on the network.
    @discardableResult
    func submitScoreIfPersonalBest(_ score: Int) -> Bool {
        guard score > personalBest else { return false }

        personalBest = score
        UserDefaults.standard.set(score, forKey: personalBestKey)

        Task { await writeLeaderboardEntry(score: score) }
        return true
    }

    /// Pushes a new high-score document into Firestore.
    private func writeLeaderboardEntry(score: Int) async {
        guard let uid = currentUserId ?? Auth.auth().currentUser?.uid else {
            print("[FirebaseManager] Cannot write score — no authenticated user")
            return
        }

        let payload: [String: Any] = [
            "userId": uid,
            "displayName": "Player-\(uid.prefix(4))",
            "score": score,
            "createdAt": Timestamp(date: Date()),
        ]

        db.collection(leaderboardCollection).addDocument(data: payload) { error in
            if let error {
                print("[FirebaseManager] Failed to write leaderboard entry: \(error)")
            }
        }
    }

    /// Fetches the top-N scores, descending. Call from the leaderboard screen
    /// (or wire to a snapshot listener for live updates).
    func fetchTopEntries(limit: Int = 25) async {
        do {
            let snapshot = try await db.collection(leaderboardCollection)
                .order(by: "score", descending: true)
                .limit(to: limit)
                .getDocuments()

            self.topEntries = snapshot.documents.compactMap(Self.entry(from:))
        } catch {
            print("[FirebaseManager] Failed to fetch leaderboard: \(error)")
        }
    }

    /// Manual decode — avoids `FirebaseFirestoreSwift` / `data(as:)`.
    private static func entry(from doc: QueryDocumentSnapshot) -> LeaderboardEntry? {
        let data = doc.data()
        guard let userId = data["userId"] as? String,
              let displayName = data["displayName"] as? String
        else { return nil }

        let score: Int
        if let s = data["score"] as? Int {
            score = s
        } else if let s64 = data["score"] as? Int64 {
            score = Int(s64)
        } else {
            return nil
        }

        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else if let date = data["createdAt"] as? Date {
            createdAt = date
        } else {
            createdAt = Date()
        }

        return LeaderboardEntry(
            id: doc.documentID,
            userId: userId,
            displayName: displayName,
            score: score,
            createdAt: createdAt
        )
    }
}
