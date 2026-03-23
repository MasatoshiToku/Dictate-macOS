import Foundation

struct TranscriptionHistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let originalText: String
    let formattedText: String
    let createdAt: Date
}
