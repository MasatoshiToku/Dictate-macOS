import Foundation

public struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var reading: String
    public var word: String
    public var category: DictionaryCategory
    public let createdAt: Date
    public var usageCount: Int

    public enum DictionaryCategory: String, Codable, Sendable {
        case auto
        case manual
    }

    public init(id: String, reading: String, word: String, category: DictionaryCategory, createdAt: Date, usageCount: Int) {
        self.id = id
        self.reading = reading
        self.word = word
        self.category = category
        self.createdAt = createdAt
        self.usageCount = usageCount
    }
}
