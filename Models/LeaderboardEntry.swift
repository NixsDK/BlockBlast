//
//  LeaderboardEntry.swift
//  BlockBlast
//
//  Codable record that maps 1:1 to a document in the Firestore `Leaderboard`
//  collection. The `@DocumentID` property wrapper is supplied by
//  FirebaseFirestoreSwift and is automatically populated with the document id
//  on read.
//

import Foundation
import FirebaseFirestore

struct LeaderboardEntry: Identifiable, Codable, Equatable {

    /// Auto-populated by Firestore when reading. Optional on write.
    @DocumentID var id: String?

    /// The Firebase Auth UID that submitted the score.
    let userId: String

    /// A human-friendly label. For anonymous users we use a short prefix of
    /// the UID; replace with a real display name if you add account linking.
    let displayName: String

    /// The score itself. Stored as `Int` so Firestore indexes order naturally.
    let score: Int

    /// Server timestamp (preferred) or fallback client timestamp.
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case displayName
        case score
        case createdAt
    }
}
