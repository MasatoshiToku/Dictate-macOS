import Foundation

struct DictionaryEntry: Codable, Identifiable, Equatable {
    let id: String
    var reading: String
    var word: String
    var category: DictionaryCategory
    let createdAt: Date
    var usageCount: Int

    enum DictionaryCategory: String, Codable {
        case auto
        case manual
    }
}
