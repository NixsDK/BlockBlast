//
//  LeaderboardEntry.swift
//  BlockBlast
//
//  Maps to documents in the Firestore `Leaderboard` collection.
//  Uses plain fields only — no FirebaseFirestoreSwift — so you only link
//  FirebaseFirestore + FirebaseAuth + FirebaseCore.
//

import Foundation

struct LeaderboardEntry: Identifiable, Equatable {

    /// Firestore document ID (from snapshot.documentID).
    let id: String

    let userId: String
    let displayName: String
    let score: Int
    let createdAt: Date
}
