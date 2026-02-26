import XCTest
@testable import DigitFlip

final class EncoderServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Build a full LetterMap from the spec's JSON (embedded here for test isolation).
    private func makeFullLetterMap() -> LetterMap {
        let json = """
        {
          "glyphSet": "classic",
          "letters": {
            "a": { "code": "0", "glyphFile": "lowercase_a.svg" },
            "b": { "code": "9", "glyphFile": "lowercase_b.svg" },
            "c": { "code": "0", "glyphFile": "lowercase_c.svg" },
            "d": { "code": "10", "glyphFile": "lowercase_d.svg" },
            "e": { "code": "2", "glyphFile": "lowercase_e.svg" },
            "f": { "code": "3", "glyphFile": "lowercase_f.svg" },
            "g": { "code": "6", "glyphFile": "lowercase_g.svg" },
            "h": { "code": "4", "glyphFile": "lowercase_h.svg" },
            "i": { "code": "1", "glyphFile": "lowercase_i.svg" },
            "j": { "code": "1", "glyphFile": "lowercase_j.svg" },
            "k": { "code": "71", "glyphFile": "lowercase_k.svg" },
            "l": { "code": "1", "glyphFile": "lowercase_l.svg" },
            "m": { "code": "41", "glyphFile": "lowercase_m.svg" },
            "n": { "code": "4", "glyphFile": "lowercase_n.svg" },
            "o": { "code": "0", "glyphFile": "lowercase_o.svg" },
            "p": { "code": "01", "glyphFile": "lowercase_p.svg" },
            "q": { "code": "6", "glyphFile": "lowercase_q.svg" },
            "r": { "code": "7", "glyphFile": "lowercase_r.svg" },
            "s": { "code": "5", "glyphFile": "lowercase_s.svg" },
            "t": { "code": "7", "glyphFile": "lowercase_t.svg" },
            "u": { "code": "0", "glyphFile": "lowercase_u.svg" },
            "v": { "code": "7", "glyphFile": "lowercase_v.svg" },
            "w": { "code": "14", "glyphFile": "lowercase_w.svg" },
            "x": { "code": "7", "glyphFile": "lowercase_x.svg" },
            "y": { "code": "6", "glyphFile": "lowercase_y.svg" },
            "z": { "code": "2", "glyphFile": "lowercase_z.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(LetterMap.self, from: data)
    }

    /// Build an EncoderService with the full letter map.
    private func makeEncoder() -> EncoderService {
        EncoderService(letterMap: makeFullLetterMap())
    }

    // MARK: - Single Letter Encoding

    func testSingleLetterA() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("a").get()
        XCTAssertEqual(result.digitDisplay, "0")
        XCTAssertEqual(result.glyphFiles, ["lowercase_a.svg"])
    }

    func testSingleLetterM_MultiDigitCode() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("m").get()
        // "m" → code "41", glyph "m.svg"
        XCTAssertEqual(result.digitDisplay, "41")
        XCTAssertEqual(result.glyphFiles, ["lowercase_m.svg"])
    }

    func testSingleLetterK_MultiDigitCode() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("k").get()
        XCTAssertEqual(result.digitDisplay, "71")
        XCTAssertEqual(result.glyphFiles, ["lowercase_k.svg"])
    }

    func testSingleLetterP_LeadingZeroCode() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("p").get()
        // "p" has code "01" — leading zero must be preserved
        XCTAssertEqual(result.digitDisplay, "01")
        XCTAssertEqual(result.glyphFiles, ["lowercase_p.svg"])
    }

    // MARK: - Multi-Letter Words

    func testHi() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("hi").get()
        // h=4, i=1; reversed: i, h → "1 4"
        XCTAssertEqual(result.digitDisplay, "1 4")
        XCTAssertEqual(result.glyphFiles, ["lowercase_i.svg", "lowercase_h.svg"])
    }

    func testMom_Palindrome() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("mom").get()
        // m=41, o=0, m=41; reversed: m, o, m → "41 0 41"
        XCTAssertEqual(result.digitDisplay, "41 0 41")
    }

    func testTop_LeadingZeroPreserved() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("top").get()
        // t=7, o=0, p=01; reversed: p, o, t → "01 0 7"
        XCTAssertEqual(result.digitDisplay, "01 0 7")
    }

    func testWord_WithMultiDigitCodes() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("desk").get()
        // d=10, e=2, s=5, k=71; reversed: k, s, e, d → "71 5 2 10"
        XCTAssertEqual(result.digitDisplay, "71 5 2 10")
    }

    // MARK: - Reversal Order

    func testReversalOrder_Abc() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("abc").get()
        // a=0, b=9, c=0; reversed: c, b, a
        XCTAssertEqual(result.elements.count, 3)
        if case .letter(let first) = result.elements[0] {
            XCTAssertEqual(first.letter, "c")
        } else { XCTFail("Expected letter") }
        if case .letter(let second) = result.elements[1] {
            XCTAssertEqual(second.letter, "b")
        } else { XCTFail("Expected letter") }
        if case .letter(let third) = result.elements[2] {
            XCTAssertEqual(third.letter, "a")
        } else { XCTFail("Expected letter") }
        XCTAssertEqual(result.digitDisplay, "0 9 0")
    }

    // MARK: - Space Handling

    func testSingleSpaceBetweenWords() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("hi you").get()
        // h=4, i=1, ' ', y=6, o=0, u=0
        // reversed: u, o, y, ' ', i, h → "0 0 6   1 4"
        XCTAssertEqual(result.digitDisplay, "0 0 6   1 4")
    }

    func testMultipleConsecutiveSpacesPreserved() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("hi  you").get()
        // h=4, i=1, ' ', ' ', y=6, o=0, u=0
        // reversed: u, o, y, ' ', ' ', i, h → "0 0 6      1 4"
        // Two spaces → two triple-spaces = 6 spaces
        XCTAssertEqual(result.digitDisplay, "0 0 6      1 4")
    }

    func testThreeConsecutiveSpaces() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("a   b").get()
        // a=0, ' ', ' ', ' ', b=9
        // reversed: b, ' ', ' ', ' ', a → "9         0" (9 spaces)
        XCTAssertEqual(result.digitDisplay, "9         0")
    }

    func testSpaceAtEdges() {
        let encoder = makeEncoder()
        // Leading space: " hi" → reversed: i, h, ' ' → "1 4   "
        let result1 = try! encoder.encode(" hi").get()
        XCTAssertEqual(result1.digitDisplay, "1 4   ")

        // Trailing space: "hi " → reversed: ' ', i, h → "   1 4"
        let result2 = try! encoder.encode("hi ").get()
        XCTAssertEqual(result2.digitDisplay, "   1 4")
    }

    // MARK: - Auto-Lowercasing

    func testAutoLowercasing() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("Hi").get()
        // "Hi" → lowercased "hi" → h=4, i=1; reversed: i, h → "1 4"
        XCTAssertEqual(result.digitDisplay, "1 4")
    }

    func testMixedCaseWord() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("MoM").get()
        XCTAssertEqual(result.digitDisplay, "41 0 41")
    }

    // MARK: - Validation: Invalid Characters

    func testInvalidCharacters_Numbers() {
        let encoder = makeEncoder()
        XCTAssertEqual(encoder.validate("hello1"), .invalidCharacters)
    }

    func testInvalidCharacters_Punctuation() {
        let encoder = makeEncoder()
        XCTAssertEqual(encoder.validate("hello!"), .invalidCharacters)
    }

    func testInvalidCharacters_SpecialChars() {
        let encoder = makeEncoder()
        XCTAssertEqual(encoder.validate("hello@world"), .invalidCharacters)
    }

    func testInvalidCharacters_AfterLowercasing() {
        let encoder = makeEncoder()
        // "Hello!" → lowercased "hello!" → '!' is invalid
        XCTAssertEqual(encoder.validate("Hello!"), .invalidCharacters)
    }

    func testValidInput_LettersOnly() {
        let encoder = makeEncoder()
        XCTAssertNil(encoder.validate("hello"))
    }

    func testValidInput_LettersAndSpaces() {
        let encoder = makeEncoder()
        XCTAssertNil(encoder.validate("hello world"))
    }

    func testValidInput_UppercaseLetters() {
        let encoder = makeEncoder()
        // Uppercase is auto-lowercased, so it's valid
        XCTAssertNil(encoder.validate("HELLO"))
    }

    // MARK: - Validation: Character Limit

    func testCharacterLimit_Exactly50() {
        let encoder = makeEncoder()
        let input = String(repeating: "a", count: 50)
        XCTAssertNil(encoder.validate(input))
    }

    func testCharacterLimit_Exceeded() {
        let encoder = makeEncoder()
        let input = String(repeating: "a", count: 51)
        XCTAssertEqual(encoder.validate(input), .characterLimitExceeded)
    }

    func testCharacterLimit_WayOver() {
        let encoder = makeEncoder()
        let input = String(repeating: "b", count: 100)
        XCTAssertEqual(encoder.validate(input), .characterLimitExceeded)
    }

    // MARK: - Validation Priority

    func testValidationPriority_InvalidCharsBeforeLimit() {
        let encoder = makeEncoder()
        // Input has both invalid chars AND exceeds limit → invalid chars wins
        let input = String(repeating: "!", count: 51)
        XCTAssertEqual(encoder.validate(input), .invalidCharacters)
    }

    // MARK: - Empty / Whitespace-Only Input

    func testIsInputEmpty_EmptyString() {
        let encoder = makeEncoder()
        XCTAssertTrue(encoder.isInputEmpty(""))
    }

    func testIsInputEmpty_WhitespaceOnly() {
        let encoder = makeEncoder()
        XCTAssertTrue(encoder.isInputEmpty("   "))
    }

    func testIsInputEmpty_WithContent() {
        let encoder = makeEncoder()
        XCTAssertFalse(encoder.isInputEmpty("hello"))
    }

    func testIsInputEmpty_SpacesAroundContent() {
        let encoder = makeEncoder()
        XCTAssertFalse(encoder.isInputEmpty(" hi "))
    }

    // MARK: - Missing Mapping

    func testMissingMapping() {
        // Create a letter map with "a" removed
        let json = """
        {
          "glyphSet": "classic",
          "letters": {
            "b": { "code": "9", "glyphFile": "b.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)
        let encoder = EncoderService(letterMap: map)

        let result = encoder.encode("ab")
        switch result {
        case .failure(.missingMapping(let char)):
            XCTAssertEqual(char, "a")
        case .success:
            XCTFail("Expected missingMapping error")
        }
    }

    func testMissingMapping_SecondLetter() {
        let json = """
        {
          "glyphSet": "test",
          "letters": {
            "a": { "code": "0", "glyphFile": "a.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)
        let encoder = EncoderService(letterMap: map)

        let result = encoder.encode("az")
        switch result {
        case .failure(.missingMapping(let char)):
            XCTAssertEqual(char, "z")
        case .success:
            XCTFail("Expected missingMapping error")
        }
    }

    // MARK: - Leading Zero Preservation (Critical)

    func testLeadingZero_P_Code01() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("p").get()
        // "p" → code "01" — NOT "1"
        XCTAssertEqual(result.digitDisplay, "01")
        XCTAssertNotEqual(result.digitDisplay, "1")
    }

    func testLeadingZero_A_Code0() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("a").get()
        // "a" → code "0" — preserved as "0", not "" or missing
        XCTAssertEqual(result.digitDisplay, "0")
        XCTAssertFalse(result.digitDisplay.isEmpty)
    }

    func testLeadingZero_InContext_TopReversed() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("top").get()
        // t=7, o=0, p=01; reversed → p, o, t → "01 0 7"
        XCTAssertEqual(result.digitDisplay, "01 0 7")
        // Verify the first code is "01" not "1"
        if case .letter(let entry) = result.elements[0] {
            XCTAssertEqual(entry.code, "01")
        } else {
            XCTFail("Expected first element to be a letter")
        }
    }

    func testLeadingZero_D_Code10() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("d").get()
        // "d" → code "10" — this has a trailing zero, not leading, but make sure it's preserved
        XCTAssertEqual(result.digitDisplay, "10")
    }

    // MARK: - Code Is String Not Integer

    func testCodeStoredAsString() {
        let map = makeFullLetterMap()
        // "p" code is "01" — if it were converted to Int and back, it would be "1"
        XCTAssertEqual(map.letters["p"]?.code, "01")
        // "a" code is "0"
        XCTAssertEqual(map.letters["a"]?.code, "0")
        // "m" code is "41"
        XCTAssertEqual(map.letters["m"]?.code, "41")
        // "d" code is "10"
        XCTAssertEqual(map.letters["d"]?.code, "10")
    }

    // MARK: - Spec Examples End-to-End

    func testSpecExample_Hi() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("hi").get()
        XCTAssertEqual(result.digitDisplay, "1 4")
    }

    func testSpecExample_Mom() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("mom").get()
        XCTAssertEqual(result.digitDisplay, "41 0 41")
    }

    func testSpecExample_HiYou() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("hi you").get()
        XCTAssertEqual(result.digitDisplay, "0 0 6   1 4")
    }

    func testSpecExample_Top() {
        let encoder = makeEncoder()
        let result = try! encoder.encode("top").get()
        XCTAssertEqual(result.digitDisplay, "01 0 7")
    }

    // MARK: - Full Alphabet Encoding

    func testAllLettersEncode() {
        let encoder = makeEncoder()
        let alphabet = "abcdefghijklmnopqrstuvwxyz"
        let result = encoder.encode(alphabet)
        switch result {
        case .success(let encoded):
            // Should have 26 letter elements
            XCTAssertEqual(encoded.elements.count, 26)
            // All should be letters (no spaces)
            for element in encoded.elements {
                if case .space = element {
                    XCTFail("Unexpected space in alphabet encoding")
                }
            }
        case .failure(let error):
            XCTFail("Encoding all letters should succeed, got: \(error)")
        }
    }
}
