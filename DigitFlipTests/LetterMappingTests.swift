import XCTest
@testable import DigitFlip

final class LetterMappingTests: XCTestCase {

    // MARK: - JSON Decoding

    func testDecodeFullLetterMap() {
        let json = """
        {
          "glyphSet": "classic",
          "letters": {
            "a": { "code": "0", "glyphFile": "a.svg" },
            "b": { "code": "9", "glyphFile": "b.svg" },
            "c": { "code": "0", "glyphFile": "c.svg" },
            "d": { "code": "10", "glyphFile": "d.svg" },
            "e": { "code": "2", "glyphFile": "e.svg" },
            "f": { "code": "3", "glyphFile": "f.svg" },
            "g": { "code": "6", "glyphFile": "g.svg" },
            "h": { "code": "4", "glyphFile": "h.svg" },
            "i": { "code": "1", "glyphFile": "i.svg" },
            "j": { "code": "1", "glyphFile": "j.svg" },
            "k": { "code": "71", "glyphFile": "k.svg" },
            "l": { "code": "1", "glyphFile": "l.svg" },
            "m": { "code": "41", "glyphFile": "m.svg" },
            "n": { "code": "4", "glyphFile": "n.svg" },
            "o": { "code": "0", "glyphFile": "o.svg" },
            "p": { "code": "01", "glyphFile": "p.svg" },
            "q": { "code": "6", "glyphFile": "q.svg" },
            "r": { "code": "1", "glyphFile": "r.svg" },
            "s": { "code": "7", "glyphFile": "s.svg" },
            "t": { "code": "0", "glyphFile": "t.svg" },
            "u": { "code": "0", "glyphFile": "u.svg" },
            "v": { "code": "7", "glyphFile": "v.svg" },
            "w": { "code": "14", "glyphFile": "w.svg" },
            "x": { "code": "7", "glyphFile": "x.svg" },
            "y": { "code": "6", "glyphFile": "y.svg" },
            "z": { "code": "2", "glyphFile": "z.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        XCTAssertEqual(map.glyphSet, "classic")
        XCTAssertEqual(map.letters.count, 26)
    }

    func testAll26LettersPresent() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        let alphabet = "abcdefghijklmnopqrstuvwxyz"
        for letter in alphabet {
            XCTAssertNotNil(
                map.letters[String(letter)],
                "Missing mapping for letter '\(letter)'"
            )
        }
    }

    func testEachEntryHasNonEmptyCodeAndGlyphFile() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        for (letter, entry) in map.letters {
            XCTAssertFalse(
                entry.code.isEmpty,
                "Letter '\(letter)' has empty code"
            )
            XCTAssertFalse(
                entry.glyphFile.isEmpty,
                "Letter '\(letter)' has empty glyphFile"
            )
        }
    }

    // MARK: - Code String Preservation

    func testCodeIsString_LeadingZeroPreserved() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        // "p" has code "01" — must NOT become "1"
        XCTAssertEqual(map.letters["p"]?.code, "01")
    }

    func testCodeIsString_ZeroPreserved() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        // "a" has code "0" — must be "0", not "" or nil
        XCTAssertEqual(map.letters["a"]?.code, "0")
    }

    func testCodeIsString_MultiDigitPreserved() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        XCTAssertEqual(map.letters["m"]?.code, "41")
        XCTAssertEqual(map.letters["k"]?.code, "71")
        XCTAssertEqual(map.letters["w"]?.code, "14")
        XCTAssertEqual(map.letters["d"]?.code, "10")
    }

    // MARK: - Glyph File Names

    func testGlyphFileNaming() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        // Each letter's glyphFile should be "<letter>.svg"
        for (letter, entry) in map.letters {
            XCTAssertEqual(
                entry.glyphFile, "\(letter).svg",
                "Glyph file for '\(letter)' should be '\(letter).svg', got '\(entry.glyphFile)'"
            )
        }
    }

    // MARK: - Malformed JSON

    func testMalformedJSON_MissingField() {
        let json = """
        {
          "glyphSet": "classic",
          "letters": {
            "a": { "code": "0" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .failure(.configurationError(let message)):
            XCTAssertTrue(message.contains("Could not load glyph configuration"))
        case .success:
            XCTFail("Should fail on malformed JSON missing glyphFile field")
        }
    }

    func testMalformedJSON_InvalidStructure() {
        let json = """
        { "not": "a valid letter map" }
        """
        let data = json.data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .failure(.configurationError):
            break // expected
        case .success:
            XCTFail("Should fail on invalid JSON structure")
        }
    }

    func testMalformedJSON_NotJSON() {
        let data = "this is not json".data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .failure(.configurationError):
            break // expected
        case .success:
            XCTFail("Should fail on non-JSON data")
        }
    }

    // MARK: - Bundle Loading via GlyphSet.decodeLetterMap

    func testDecodeLetterMap_ValidJSON() {
        let json = loadSpecJSON()
        let data = json.data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .success(let map):
            XCTAssertEqual(map.glyphSet, "classic")
            XCTAssertEqual(map.letters.count, 26)
        case .failure(let error):
            XCTFail("Should successfully decode valid JSON, got: \(error)")
        }
    }

    // MARK: - Helpers

    private func loadSpecJSON() -> String {
        """
        {
          "glyphSet": "classic",
          "letters": {
            "a": { "code": "0", "glyphFile": "a.svg" },
            "b": { "code": "9", "glyphFile": "b.svg" },
            "c": { "code": "0", "glyphFile": "c.svg" },
            "d": { "code": "10", "glyphFile": "d.svg" },
            "e": { "code": "2", "glyphFile": "e.svg" },
            "f": { "code": "3", "glyphFile": "f.svg" },
            "g": { "code": "6", "glyphFile": "g.svg" },
            "h": { "code": "4", "glyphFile": "h.svg" },
            "i": { "code": "1", "glyphFile": "i.svg" },
            "j": { "code": "1", "glyphFile": "j.svg" },
            "k": { "code": "71", "glyphFile": "k.svg" },
            "l": { "code": "1", "glyphFile": "l.svg" },
            "m": { "code": "41", "glyphFile": "m.svg" },
            "n": { "code": "4", "glyphFile": "n.svg" },
            "o": { "code": "0", "glyphFile": "o.svg" },
            "p": { "code": "01", "glyphFile": "p.svg" },
            "q": { "code": "6", "glyphFile": "q.svg" },
            "r": { "code": "1", "glyphFile": "r.svg" },
            "s": { "code": "7", "glyphFile": "s.svg" },
            "t": { "code": "0", "glyphFile": "t.svg" },
            "u": { "code": "0", "glyphFile": "u.svg" },
            "v": { "code": "7", "glyphFile": "v.svg" },
            "w": { "code": "14", "glyphFile": "w.svg" },
            "x": { "code": "7", "glyphFile": "x.svg" },
            "y": { "code": "6", "glyphFile": "y.svg" },
            "z": { "code": "2", "glyphFile": "z.svg" }
          }
        }
        """
    }
}
