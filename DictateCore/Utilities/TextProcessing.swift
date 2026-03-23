import Foundation

public enum TextProcessing {
    // Unicode ranges for Japanese characters (ICU regex syntax for NSRegularExpression)
    private static let jpPattern = "[\\u3000-\\u303F\\u3040-\\u309F\\u30A0-\\u30FF\\u4E00-\\u9FFF\\uFF00-\\uFFEF]"
    private static let spPattern = "[ \\t]+"

    private static let jpToJpSpace: NSRegularExpression = {
        try! NSRegularExpression(pattern: "(\(jpPattern))\(spPattern)(\(jpPattern))")
    }()

    private static let jpToAsciiSpace: NSRegularExpression = {
        try! NSRegularExpression(pattern: "(\(jpPattern))\(spPattern)([a-zA-Z0-9])")
    }()

    private static let asciiToJpSpace: NSRegularExpression = {
        try! NSRegularExpression(pattern: "([a-zA-Z0-9])\(spPattern)(\(jpPattern))")
    }()

    private static let fullWidthSpace: NSRegularExpression = {
        try! NSRegularExpression(pattern: "\\u3000")
    }()

    private static let maxIterations = 100

    public static func removeJapaneseSpaces(_ text: String) -> String {
        var result = text
        var prev = ""
        var iterations = 0

        while result != prev && iterations < maxIterations {
            prev = result
            let range = NSRange(result.startIndex..<result.endIndex, in: result)

            result = jpToJpSpace.stringByReplacingMatches(in: result, range: range, withTemplate: "$1$2")
            let range2 = NSRange(result.startIndex..<result.endIndex, in: result)
            result = jpToAsciiSpace.stringByReplacingMatches(in: result, range: range2, withTemplate: "$1$2")
            let range3 = NSRange(result.startIndex..<result.endIndex, in: result)
            result = asciiToJpSpace.stringByReplacingMatches(in: result, range: range3, withTemplate: "$1$2")
            iterations += 1
        }

        let range4 = NSRange(result.startIndex..<result.endIndex, in: result)
        result = fullWidthSpace.stringByReplacingMatches(in: result, range: range4, withTemplate: "")

        return result
    }

    /// Check if text requires clipboard paste (contains non-ASCII characters)
    public static func requiresClipboard(for text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return value < 0x20 || value > 0x7E
        } && text.contains(where: { char in
            let scalars = char.unicodeScalars
            guard let first = scalars.first else { return false }
            return first.value > 0x7E
        })
    }

    // MARK: - Punctuation-aware comparison

    private static let sentencePunct = CharacterSet(charactersIn: "\u{3002}\u{3001}\u{FF01}\u{FF1F}!?,. \t\n\r")

    private static func stripPunct(_ text: String) -> String {
        return text.unicodeScalars.filter { !sentencePunct.contains($0) }.map { String($0) }.joined()
    }

    public static func contentEquals(_ a: String, _ b: String) -> Bool {
        return stripPunct(a) == stripPunct(b)
    }

    /// Compute delta (new text) between previously typed text and new transcription.
    public static func computeDelta(previousText: String, newText: String) -> String {
        if newText.isEmpty { return "" }
        if previousText.isEmpty { return newText }

        // Fast path: exact prefix match
        if newText.hasPrefix(previousText) {
            return String(newText.dropFirst(previousText.count))
        }

        // Fuzzy match: strip punctuation and compare content
        let contentPrev = stripPunct(previousText)
        let contentNew = stripPunct(newText)

        if contentNew == contentPrev { return "" }
        guard contentNew.hasPrefix(contentPrev) else { return "" }

        // Walk through newText to find where previously-typed content ends
        var matchIdx = contentPrev.startIndex
        var scanIdx = newText.startIndex

        while matchIdx < contentPrev.endIndex && scanIdx < newText.endIndex {
            let scanChar = newText[scanIdx]
            if "\u{3002}\u{3001}\u{FF01}\u{FF1F}!?,. \t\n\r".contains(scanChar) {
                scanIdx = newText.index(after: scanIdx)
                continue
            }
            if newText[scanIdx] == contentPrev[matchIdx] {
                matchIdx = contentPrev.index(after: matchIdx)
                scanIdx = newText.index(after: scanIdx)
            } else {
                return ""
            }
        }

        guard matchIdx >= contentPrev.endIndex else { return "" }
        return String(newText[scanIdx...])
    }
}
