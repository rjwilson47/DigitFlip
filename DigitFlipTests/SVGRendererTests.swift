import XCTest
@testable import DigitFlip

final class SVGRendererTests: XCTestCase {

    // MARK: - SVG Parser: Placeholder SVGs

    func testParsePlaceholderSVG_ProducesValidGlyph() {
        let svg = GlyphSet.placeholderSVG(letter: "m", code: "41")
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph, "Placeholder SVG should parse successfully")
    }

    func testParsePlaceholderSVG_HasCorrectViewBox() {
        let svg = GlyphSet.placeholderSVG(letter: "a", code: "0")
        let glyph = SVGParser.parse(svgString: svg)!
        XCTAssertEqual(glyph.viewBox.origin.x, 0)
        XCTAssertEqual(glyph.viewBox.origin.y, 0)
        XCTAssertEqual(glyph.viewBox.width, 60)
        XCTAssertEqual(glyph.viewBox.height, 80)
    }

    func testParsePlaceholderSVG_ContainsRectElement() {
        let svg = GlyphSet.placeholderSVG(letter: "b", code: "9")
        let glyph = SVGParser.parse(svgString: svg)!
        XCTAssertFalse(glyph.pathElements.isEmpty, "Placeholder should have at least one rect path element")
    }

    func testParsePlaceholderSVG_ContainsTextElements() {
        let svg = GlyphSet.placeholderSVG(letter: "k", code: "71")
        let glyph = SVGParser.parse(svgString: svg)!
        XCTAssertEqual(glyph.textElements.count, 2, "Placeholder should have two text elements (letter + code)")
    }

    func testParsePlaceholderSVG_TextContentMatches() {
        let svg = GlyphSet.placeholderSVG(letter: "p", code: "01")
        let glyph = SVGParser.parse(svgString: svg)!
        let texts = glyph.textElements.map(\.content)
        XCTAssertTrue(texts.contains("p"), "Should contain letter text")
        XCTAssertTrue(texts.contains("01"), "Should contain code text with leading zero")
    }

    func testParsePlaceholderSVG_AllLettersParse() {
        let letters: [(String, String)] = [
            ("a", "0"), ("b", "9"), ("c", "0"), ("d", "10"), ("e", "2"),
            ("f", "3"), ("g", "6"), ("h", "4"), ("i", "1"), ("j", "1"),
            ("k", "71"), ("l", "1"), ("m", "41"), ("n", "4"), ("o", "0"),
            ("p", "01"), ("q", "6"), ("r", "7"), ("s", "5"), ("t", "7"),
            ("u", "0"), ("v", "7"), ("w", "14"), ("x", "7"), ("y", "6"),
            ("z", "2")
        ]
        for (letter, code) in letters {
            let svg = GlyphSet.placeholderSVG(letter: letter, code: code)
            let glyph = SVGParser.parse(svgString: svg)
            XCTAssertNotNil(glyph, "Placeholder for '\(letter)' should parse")
        }
    }

    // MARK: - SVG Parser: Real SVG Paths

    func testParseSimplePath_MoveTo() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 10 20 L 30 40 Z" fill="#000000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testParseSimplePath_ViewBoxParsed() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 264.58 264.58">
          <path d="M 10 20 L 30 40" fill="#000000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)!
        XCTAssertEqual(glyph.viewBox.width, 264.58, accuracy: 0.01)
        XCTAssertEqual(glyph.viewBox.height, 264.58, accuracy: 0.01)
    }

    func testParseRelativePath_Lowercase() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="m 10,20 l 30,40 z" fill="#000000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testParseEllipticalArc() {
        // Based on the actual a.svg pattern
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 264.58 264.58">
          <path d="M 132.29 39.69 A 99.22 90.40 0 0 0 33.07 130.09 A 99.22 90.40 0 0 0 132.29 220.49 Z" fill="#000000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph, "SVG with elliptical arc commands should parse")
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testParseRect() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="10" y="20" width="30" height="40" fill="#FF0000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testParseRoundedRect() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 80">
          <rect x="2" y="2" width="56" height="76" rx="8" fill="#1a1a2e" stroke="#e94560" stroke-width="2"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testParseGroup_WithTransform() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 264.58 264.58">
          <g transform="matrix(0.65,0,0,0.67,20,13)">
            <path d="M 132 40 L 232 130 L 132 220 Z" fill="#000000"/>
          </g>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph, "SVG with group transform should parse")
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testParseMultiplePaths() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 10 10 L 90 10" fill="#000000"/>
          <path d="M 10 50 L 90 50" fill="#000000"/>
          <path d="M 10 90 L 90 90" fill="#000000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 3)
    }

    // MARK: - SVG Parser: Style Parsing

    func testParseStyleAttribute_Fill() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 0 0 L 100 100" style="fill:#FF0000;stroke:none"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)!
        let element = glyph.pathElements[0]
        // Verify fill is red
        let components = element.fillColor.components ?? []
        XCTAssertEqual(components.count, 4) // RGBA
        XCTAssertEqual(components[0], 1.0, accuracy: 0.01) // Red
    }

    func testParseDirectFillAttribute() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="#00FF00"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)!
        let element = glyph.pathElements[0]
        let components = element.fillColor.components ?? []
        XCTAssertEqual(components[1], 1.0, accuracy: 0.01) // Green
    }

    // MARK: - SVG Parser: Edge Cases

    func testParseInvalidSVG_ReturnsNil() {
        let glyph = SVGParser.parse(svgString: "not svg at all")
        XCTAssertNil(glyph)
    }

    func testParseEmptyString_ReturnsNil() {
        let glyph = SVGParser.parse(svgString: "")
        XCTAssertNil(glyph)
    }

    func testParseSVG_NoPathElements() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph, "Empty SVG is still valid")
        XCTAssertTrue(glyph!.pathElements.isEmpty)
    }

    func testParseSVG_WidthHeightFallback() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="300">
          <path d="M 0 0 L 100 100" fill="#000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)!
        XCTAssertEqual(glyph.viewBox.width, 200)
        XCTAssertEqual(glyph.viewBox.height, 300)
    }

    // MARK: - SVG Path Commands

    func testPathCommand_HorizontalLine() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 10 10 H 90" fill="#000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testPathCommand_VerticalLine() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 10 10 V 90" fill="#000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph!.pathElements.count, 1)
    }

    func testPathCommand_CubicBezier() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 10 80 C 40 10, 65 10, 95 80" fill="#000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
    }

    func testPathCommand_ClosePath() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <path d="M 10 10 L 90 10 L 50 90 Z" fill="#000"/>
        </svg>
        """
        let glyph = SVGParser.parse(svgString: svg)
        XCTAssertNotNil(glyph)
    }

    // MARK: - GlyphCache

    func testGlyphCache_PlaceholderFallback() {
        let json = """
        {
          "glyphSet": "test",
          "displayName": "Test",
          "status": "available",
          "letters": {
            "z": { "code": "2", "glyphFile": "z.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        let cache = GlyphCache(glyphSetName: "test")
        cache.preload(letterMap: map)

        // z.svg doesn't exist in any bundle, so it should fall back to placeholder
        let glyph = cache.glyph(forLetter: "z", code: "2", glyphFile: "z.svg")
        XCTAssertNotNil(glyph, "Missing glyph file should produce placeholder, not nil")
    }

    func testGlyphCache_PlaceholderHasTextElements() {
        let json = """
        {
          "glyphSet": "test",
          "displayName": "Test",
          "status": "available",
          "letters": {
            "m": { "code": "41", "glyphFile": "m.svg" }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        let cache = GlyphCache(glyphSetName: "test")
        cache.preload(letterMap: map)

        let glyph = cache.glyph(forLetter: "m", code: "41", glyphFile: "m.svg")!
        let texts = glyph.textElements.map(\.content)
        XCTAssertTrue(texts.contains("m"))
        XCTAssertTrue(texts.contains("41"))
    }

    func testGlyphCache_Invalidate() {
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
        let map = try! JSONDecoder().decode(LetterMap.self, from: data)

        let cache = GlyphCache(glyphSetName: "test")
        cache.preload(letterMap: map)

        // Glyph should be cached
        XCTAssertNotNil(cache.glyph(for: "a.svg"))

        // After invalidation, direct lookup returns nil (lazy reload needed)
        cache.invalidate()
        XCTAssertNil(cache.glyph(for: "a.svg"))
    }

    func testGlyphCache_OnDemandLoading() {
        let cache = GlyphCache(glyphSetName: "test")
        // Don't call preload — use on-demand loading
        let glyph = cache.glyph(forLetter: "x", code: "7", glyphFile: "x.svg")
        XCTAssertNotNil(glyph, "On-demand loading should produce placeholder for missing file")
    }

    // MARK: - Same Pipeline Verification

    func testSamePipeline_FileAndPlaceholder_BothParseToParsedGlyph() {
        // File-based SVG (simple)
        let fileSVG = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 264.58 264.58">
          <path d="M 132 40 A 99 90 0 0 0 33 130 A 99 90 0 0 0 132 220 Z" fill="#000"/>
        </svg>
        """
        let fileGlyph = SVGParser.parse(svgString: fileSVG)

        // Placeholder SVG
        let placeholderSVG = GlyphSet.placeholderSVG(letter: "a", code: "0")
        let placeholderGlyph = SVGParser.parse(svgString: placeholderSVG)

        // Both go through same parser and produce the same type
        XCTAssertNotNil(fileGlyph)
        XCTAssertNotNil(placeholderGlyph)
        // Both have valid viewBoxes
        XCTAssertTrue(fileGlyph!.viewBox.width > 0)
        XCTAssertTrue(placeholderGlyph!.viewBox.width > 0)
    }
}
