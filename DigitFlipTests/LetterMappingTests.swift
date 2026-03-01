import XCTest
@testable import DigitFlip

final class LetterMappingTests: XCTestCase {

    // MARK: - JSON Decoding

    func testDecodeFullLetterMap() {
        let json = """
        {
          "glyphSet": "classic",
          "displayName": "Digitext",
          "status": "available",
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

        // Each letter's glyphFile should be "lowercase_<letter>.svg"
        for (letter, entry) in map.letters {
            XCTAssertEqual(
                entry.glyphFile, "lowercase_\(letter).svg",
                "Glyph file for '\(letter)' should be 'lowercase_\(letter).svg', got '\(entry.glyphFile)'"
            )
        }
    }

    // MARK: - Malformed JSON

    func testMalformedJSON_MissingField() {
        let json = """
        {
          "glyphSet": "classic",
          "displayName": "Digitext",
          "status": "available",
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
          "displayName": "Digitext",
          "status": "available",
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
    }
}
