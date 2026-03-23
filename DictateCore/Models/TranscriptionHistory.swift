import Foundation

public struct TranscriptionHistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let originalText: String
    public let formattedText: String
    public let createdAt: Date

    public init(id: String, originalText: String, formattedText: String, createdAt: Date) {
        self.id = id
        self.originalText = originalText
        self.formattedText = formattedText
        self.createdAt = createdAt
    }
}
