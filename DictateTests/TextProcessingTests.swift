import Testing
@testable import DictateCore

@Suite("TextProcessing")
struct TextProcessingTests {
    @Test("Remove spaces between kanji")
    func spaceBetweenKanji() {
        #expect(TextProcessing.removeJapaneseSpaces("\u{6771}\u{4EAC} \u{30BF}\u{30EF}\u{30FC}") == "\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}")
    }

    @Test("Remove spaces between Japanese and ASCII")
    func spaceBetweenJpAndAscii() {
        #expect(TextProcessing.removeJapaneseSpaces("\u{30C6}\u{30B9}\u{30C8} abc \u{30C6}\u{30B9}\u{30C8}") == "\u{30C6}\u{30B9}\u{30C8}abc\u{30C6}\u{30B9}\u{30C8}")
    }

    @Test("Remove full-width spaces")
    func fullWidthSpaces() {
        #expect(TextProcessing.removeJapaneseSpaces("\u{6771}\u{4EAC}\u{3000}\u{30BF}\u{30EF}\u{30FC}") == "\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}")
    }

    @Test("Preserve spaces between ASCII characters")
    func preserveAsciiSpaces() {
        #expect(TextProcessing.removeJapaneseSpaces("hello world") == "hello world")
    }

    @Test("Handle empty string")
    func emptyString() {
        #expect(TextProcessing.removeJapaneseSpaces("") == "")
    }

    @Test("Preserve newlines")
    func preserveNewlines() {
        #expect(TextProcessing.removeJapaneseSpaces("\u{6771}\u{4EAC}\n\u{30BF}\u{30EF}\u{30FC}") == "\u{6771}\u{4EAC}\n\u{30BF}\u{30EF}\u{30FC}")
    }

    @Test("Remove tabs between Japanese")
    func removeTabs() {
        #expect(TextProcessing.removeJapaneseSpaces("\u{6771}\u{4EAC}\t\u{30BF}\u{30EF}\u{30FC}") == "\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}")
    }

    @Test("Idempotent - applying twice yields same result")
    func idempotent() {
        let input = "\u{6771}\u{4EAC} \u{30BF}\u{30EF}\u{30FC} test \u{5927}\u{962A} \u{57CE}"
        let once = TextProcessing.removeJapaneseSpaces(input)
        let twice = TextProcessing.removeJapaneseSpaces(once)
        #expect(once == twice)
    }

    @Test("Requires clipboard for non-ASCII")
    func requiresClipboard() {
        #expect(TextProcessing.requiresClipboard(for: "hello world") == false)
        #expect(TextProcessing.requiresClipboard(for: "\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}") == true)
        #expect(TextProcessing.requiresClipboard(for: "hello \u{6771}\u{4EAC}") == true)
    }

    @Test("Content equals ignoring punctuation")
    func contentEquals() {
        #expect(TextProcessing.contentEquals("\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}", "\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}\u{3002}") == true)
        #expect(TextProcessing.contentEquals("\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}", "\u{5927}\u{962A}\u{57CE}") == false)
    }

    @Test("Compute delta between previous and new text")
    func computeDelta() {
        #expect(TextProcessing.computeDelta(previousText: "\u{6771}\u{4EAC}", newText: "\u{6771}\u{4EAC}\u{30BF}\u{30EF}\u{30FC}") == "\u{30BF}\u{30EF}\u{30FC}")
        #expect(TextProcessing.computeDelta(previousText: "", newText: "\u{6771}\u{4EAC}") == "\u{6771}\u{4EAC}")
        #expect(TextProcessing.computeDelta(previousText: "\u{6771}\u{4EAC}", newText: "\u{6771}\u{4EAC}") == "")
        #expect(TextProcessing.computeDelta(previousText: "\u{6771}\u{4EAC}", newText: "") == "")
    }
}
