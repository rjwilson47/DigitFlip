import XCTest
@testable import DigitFlip

final class GlyphSetTests: XCTestCase {

    // MARK: - Placeholder SVG Generation

    func testPlaceholderSVG_ContainsLetter() {
        let svg = GlyphSet.placeholderSVG(letter: "m", code: "41")
        XCTAssertTrue(svg.contains(">m<"), "Placeholder should contain the letter 'm'")
    }

    func testPlaceholderSVG_ContainsCode() {
        let svg = GlyphSet.placeholderSVG(letter: "m", code: "41")
        XCTAssertTrue(svg.contains(">41<"), "Placeholder should contain the code '41'")
    }

    func testPlaceholderSVG_IsValidSVGStructure() {
        let svg = GlyphSet.placeholderSVG(letter: "a", code: "0")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
        XCTAssertTrue(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
    }

    func testPlaceholderSVG_HasCorrectDimensions() {
        let svg = GlyphSet.placeholderSVG(letter: "a", code: "0")
        XCTAssertTrue(svg.contains("width=\"60\""))
        XCTAssertTrue(svg.contains("height=\"80\""))
        XCTAssertTrue(svg.contains("viewBox=\"0 0 60 80\""))
    }

    func testPlaceholderSVG_LeadingZeroCode() {
        let svg = GlyphSet.placeholderSVG(letter: "p", code: "01")
        // The placeholder should show "01", not "1"
        XCTAssertTrue(svg.contains(">01<"), "Placeholder should preserve leading zero in code")
        XCTAssertTrue(svg.contains(">p<"), "Placeholder should contain the letter")
    }

    func testPlaceholderSVG_DifferentLettersProduceDifferentSVGs() {
        let svgA = GlyphSet.placeholderSVG(letter: "a", code: "0")
        let svgB = GlyphSet.placeholderSVG(letter: "b", code: "9")
        XCTAssertNotEqual(svgA, svgB)
    }

    func testPlaceholderSVG_NotEmpty() {
        let svg = GlyphSet.placeholderSVG(letter: "z", code: "2")
        XCTAssertFalse(svg.isEmpty)
    }

    // MARK: - decodeLetterMap from Data

    func testDecodeLetterMap_ValidData() {
        let json = """
        {
          "glyphSet": "test",
          "displayName": "Test",
          "status": "available",
          "letters": {
            "a": { "code": "0", "glyphFile": "a.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .success(let map):
            XCTAssertEqual(map.glyphSet, "test")
            XCTAssertEqual(map.letters.count, 1)
            XCTAssertEqual(map.letters["a"]?.code, "0")
        case .failure:
            XCTFail("Should decode valid JSON")
        }
    }

    func testDecodeLetterMap_InvalidData() {
        let data = "not json".data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .failure(.configurationError(let message)):
            XCTAssertTrue(message.contains("Could not load glyph configuration"))
        case .success:
            XCTFail("Should fail on invalid data")
        }
    }

    func testDecodeLetterMap_EmptyLetters() {
        let json = """
        {
          "glyphSet": "empty",
          "displayName": "Empty",
          "status": "available",
          "letters": {}
        }
        """
        let data = json.data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .success(let map):
            XCTAssertEqual(map.glyphSet, "empty")
            XCTAssertEqual(map.letters.count, 0)
        case .failure:
            XCTFail("Empty letters dict is structurally valid")
        }
    }

    // MARK: - Glyph File Resolution (No-File Fallback)

    func testGlyphFileExists_NonexistentFile() {
        // With no documents dir and an empty bundle stand-in, file should not exist
        let exists = GlyphSet.glyphFileExists(
            fileName: "nonexistent.svg",
            glyphSetName: "classic",
            documentsDirectory: nil,
            bundle: Bundle(for: type(of: self))
        )
        XCTAssertFalse(exists, "Nonexistent glyph file should return false")
    }

    func testResolveGlyphFileURL_NonexistentFile() {
        let url = GlyphSet.resolveGlyphFileURL(
            fileName: "nonexistent.svg",
            glyphSetName: "classic",
            documentsDirectory: nil,
            bundle: Bundle(for: type(of: self))
        )
        XCTAssertNil(url, "Nonexistent glyph should resolve to nil (triggering placeholder)")
    }

    // MARK: - Placeholder Fallback Integration

    func testPlaceholderFallback_MissingGlyphGetsPlaceholder() {
        // Simulate: glyph file doesn't exist → generate placeholder
        let fileName = "z.svg" // unlikely to be in the test bundle
        let exists = GlyphSet.glyphFileExists(
            fileName: fileName,
            glyphSetName: "classic",
            documentsDirectory: nil,
            bundle: Bundle(for: type(of: self))
        )

        if !exists {
            // Fallback to placeholder — should produce a valid SVG string, not nil or crash
            let placeholder = GlyphSet.placeholderSVG(letter: "z", code: "2")
            XCTAssertFalse(placeholder.isEmpty)
            XCTAssertTrue(placeholder.contains("<svg"))
            XCTAssertTrue(placeholder.contains(">z<"))
            XCTAssertTrue(placeholder.contains(">2<"))
        } else {
            // If somehow it exists, that's also fine
        }
    }

    func testPlaceholderFallback_AllMissingLettersGetPlaceholders() {
        let letters: [(String, String)] = [
            ("d", "10"), ("e", "2"), ("f", "3"), ("g", "6"),
            ("h", "4"), ("i", "1"), ("j", "1"), ("k", "71"),
            ("l", "1"), ("m", "41"), ("n", "4"), ("p", "01"),
            ("q", "6"), ("r", "7"), ("s", "7"), ("t", "0"),
            ("u", "0"), ("v", "7"), ("w", "14"), ("x", "7"),
            ("y", "6"), ("z", "2")
        ]

        for (letter, code) in letters {
            let placeholder = GlyphSet.placeholderSVG(letter: letter, code: code)
            XCTAssertTrue(
                placeholder.contains(">\(letter)<"),
                "Placeholder for '\(letter)' should contain the letter"
            )
            XCTAssertTrue(
                placeholder.contains(">\(code)<"),
                "Placeholder for '\(letter)' should contain code '\(code)'"
            )
        }
    }

    // MARK: - GlyphSetInfo

    func testGlyphSetInfo_AvailableStatus() {
        let info = GlyphSetInfo(glyphSet: "classic", displayName: "Digitext", status: "available")
        XCTAssertTrue(info.isAvailable)
        XCTAssertEqual(info.id, "classic")
    }

    func testGlyphSetInfo_ComingSoonStatus() {
        let info = GlyphSetInfo(glyphSet: "no_zero", displayName: "Digitext without 0", status: "coming_soon")
        XCTAssertFalse(info.isAvailable)
        XCTAssertEqual(info.id, "no_zero")
    }

    func testLetterMap_IncludesDisplayNameAndStatus() {
        let json = """
        {
          "glyphSet": "classic",
          "displayName": "Digitext",
          "status": "available",
          "letters": {
            "a": { "code": "0", "glyphFile": "lowercase_a.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let result = GlyphSet.decodeLetterMap(from: data)

        switch result {
        case .success(let map):
            XCTAssertEqual(map.displayName, "Digitext")
            XCTAssertEqual(map.status, "available")
        case .failure:
            XCTFail("Should decode valid JSON with displayName and status")
        }
    }
}
