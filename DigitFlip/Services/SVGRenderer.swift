import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Parsed Glyph Data Model

/// A fully parsed SVG glyph, ready for rendering.
struct ParsedGlyph {
    let viewBox: CGRect
    let pathElements: [PathElement]
    let textElements: [TextElement]
}

/// A single shape (path or rect) with fill and optional stroke.
struct PathElement {
    let path: CGPath
    let fillColor: CGColor
    let strokeColor: CGColor?
    let strokeWidth: CGFloat
}

/// A text element from the SVG (used in placeholder glyphs).
struct TextElement {
    let content: String
    let x: CGFloat
    let y: CGFloat
    let fontSize: CGFloat
    let fillColor: Color
    let anchor: UnitPoint // .center for "middle", .leading for "start"
}

// MARK: - Glyph Cache

/// Caches parsed glyphs keyed by "glyphSetName/glyphFile".
/// Built when a glyph set is loaded, reused across Go taps.
final class GlyphCache {
    private var cache: [String: ParsedGlyph] = [:]
    private let glyphSetName: String

    init(glyphSetName: String) {
        self.glyphSetName = glyphSetName
    }

    /// Pre-load all glyphs from a letter map.
    func loadAll(letterMap: LetterMap) {
        for (letter, entry) in letterMap.letters {
            let key = cacheKey(for: entry.glyphFile)
            if cache[key] != nil { continue }

            // Try file-based SVG (tier 1 & 2)
            if let url = GlyphSet.resolveGlyphFileURL(
                fileName: entry.glyphFile,
                glyphSetName: glyphSetName
            ),
               let data = try? Data(contentsOf: url),
               let svgString = String(data: data, encoding: .utf8)
            {
                if let parsed = SVGParser.parse(svgString: svgString) {
                    cache[key] = parsed
                    continue
                }
            }

            // Tier 3: placeholder
            let placeholder = GlyphSet.placeholderSVG(letter: letter, code: entry.code)
            if let parsed = SVGParser.parse(svgString: placeholder) {
                cache[key] = parsed
            }
        }
    }

    /// Retrieve a cached glyph by its SVG filename.
    func glyph(for glyphFile: String) -> ParsedGlyph? {
        cache[cacheKey(for: glyphFile)]
    }

    /// Retrieve a glyph, loading on demand if not cached.
    func glyph(forLetter letter: String, code: String, glyphFile: String) -> ParsedGlyph? {
        let key = cacheKey(for: glyphFile)
        if let cached = cache[key] { return cached }

        // Try file
        if let url = GlyphSet.resolveGlyphFileURL(
            fileName: glyphFile,
            glyphSetName: glyphSetName
        ),
           let data = try? Data(contentsOf: url),
           let svgString = String(data: data, encoding: .utf8),
           let parsed = SVGParser.parse(svgString: svgString)
        {
            cache[key] = parsed
            return parsed
        }

        // Placeholder
        let placeholder = GlyphSet.placeholderSVG(letter: letter, code: code)
        if let parsed = SVGParser.parse(svgString: placeholder) {
            cache[key] = parsed
            return parsed
        }

        return nil
    }

    /// Invalidate the entire cache (call when glyph set changes).
    func invalidate() {
        cache.removeAll()
    }

    private func cacheKey(for glyphFile: String) -> String {
        "\(glyphSetName)/\(glyphFile)"
    }
}

// MARK: - SVG Parser (XML-based)

/// Parses SVG XML into a `ParsedGlyph` containing paths, rects, and text elements.
enum SVGParser {

    static func parse(svgString: String) -> ParsedGlyph? {
        guard let data = svgString.data(using: .utf8) else { return nil }
        let delegate = SVGXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return ParsedGlyph(
            viewBox: delegate.viewBox,
            pathElements: delegate.pathElements,
            textElements: delegate.textElements
        )
    }
}

// MARK: - XMLParser Delegate

private class SVGXMLParserDelegate: NSObject, XMLParserDelegate {
    var viewBox: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100)
    var pathElements: [PathElement] = []
    var textElements: [TextElement] = []

    private var transformStack: [CGAffineTransform] = [.identity]
    private var currentTransform: CGAffineTransform { transformStack.last ?? .identity }

    // For <text> parsing
    private var parsingText = false
    private var textContent = ""
    private var textAttrs: [String: String] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        switch elementName {
        case "svg":
            parseSVGElement(attributes)
        case "g":
            pushTransform(attributes)
        case "path":
            parsePath(attributes)
        case "rect":
            parseRect(attributes)
        case "text":
            parsingText = true
            textContent = ""
            textAttrs = attributes
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "g":
            popTransform()
        case "text":
            if parsingText {
                buildTextElement()
                parsingText = false
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if parsingText {
            textContent += string
        }
    }

    // MARK: - SVG Element

    private func parseSVGElement(_ attrs: [String: String]) {
        if let vb = attrs["viewBox"] {
            let parts = vb.split(whereSeparator: { $0 == " " || $0 == "," })
                .compactMap { Double($0) }
            if parts.count == 4 {
                viewBox = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
            }
        } else if let w = attrs["width"].flatMap(Double.init),
                  let h = attrs["height"].flatMap(Double.init) {
            viewBox = CGRect(x: 0, y: 0, width: w, height: h)
        }
    }

    // MARK: - Transform Stack

    private func pushTransform(_ attrs: [String: String]) {
        var transform = currentTransform
        if let t = attrs["transform"] {
            let parsed = parseTransform(t)
            transform = parsed.concatenating(transform)
        }
        transformStack.append(transform)
    }

    private func popTransform() {
        if transformStack.count > 1 {
            transformStack.removeLast()
        }
    }

    private func parseTransform(_ value: String) -> CGAffineTransform {
        // Handle matrix(a,b,c,d,e,f)
        if value.hasPrefix("matrix(") {
            let inner = value
                .dropFirst(7)
                .dropLast(value.hasSuffix(")") ? 1 : 0)
            let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Double($0) }
            if parts.count == 6 {
                return CGAffineTransform(
                    a: parts[0], b: parts[1],
                    c: parts[2], d: parts[3],
                    tx: parts[4], ty: parts[5]
                )
            }
        }
        // Handle translate(tx, ty)
        if value.hasPrefix("translate(") {
            let inner = value
                .dropFirst(10)
                .dropLast(value.hasSuffix(")") ? 1 : 0)
            let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Double($0) }
            if parts.count >= 1 {
                let tx = parts[0]
                let ty = parts.count >= 2 ? parts[1] : 0
                return CGAffineTransform(translationX: tx, y: ty)
            }
        }
        // Handle scale(sx, sy)
        if value.hasPrefix("scale(") {
            let inner = value
                .dropFirst(6)
                .dropLast(value.hasSuffix(")") ? 1 : 0)
            let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Double($0) }
            if parts.count >= 1 {
                let sx = parts[0]
                let sy = parts.count >= 2 ? parts[1] : sx
                return CGAffineTransform(scaleX: sx, y: sy)
            }
        }
        // Handle rotate(angle) or rotate(angle, cx, cy)
        if value.hasPrefix("rotate(") {
            let inner = value
                .dropFirst(7)
                .dropLast(value.hasSuffix(")") ? 1 : 0)
            let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Double($0) }
            if parts.count >= 1 {
                let angle = parts[0] * .pi / 180.0
                if parts.count >= 3 {
                    let cx = parts[1], cy = parts[2]
                    var t = CGAffineTransform(translationX: cx, y: cy)
                    t = t.rotated(by: angle)
                    t = t.translatedBy(x: -cx, y: -cy)
                    return t
                }
                return CGAffineTransform(rotationAngle: angle)
            }
        }
        return .identity
    }

    // MARK: - Path Element

    private func parsePath(_ attrs: [String: String]) {
        guard let d = attrs["d"] else { return }
        let styles = resolveStyles(attrs)
        let fillColor = parseColor(styles["fill"] ?? "#000000") ?? CGColor(gray: 0, alpha: 1)
        let strokeColorStr = styles["stroke"]
        let strokeColor = (strokeColorStr != nil && strokeColorStr != "none")
            ? parseColor(strokeColorStr!) : nil
        let strokeWidth = Double(styles["stroke-width"] ?? "0") ?? 0

        guard let basePath = SVGPathDataParser.parse(d) else { return }

        var transform = currentTransform
        if let t = attrs["transform"] {
            let local = parseTransform(t)
            transform = local.concatenating(transform)
        }

        let transformedPath = basePath.copy(using: &transform) ?? basePath

        pathElements.append(PathElement(
            path: transformedPath,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth
        ))
    }

    // MARK: - Rect Element

    private func parseRect(_ attrs: [String: String]) {
        let styles = resolveStyles(attrs)
        let x = Double(attrs["x"] ?? "0") ?? 0
        let y = Double(attrs["y"] ?? "0") ?? 0
        let w = Double(attrs["width"] ?? "0") ?? 0
        let h = Double(attrs["height"] ?? "0") ?? 0
        let rx = Double(attrs["rx"] ?? "0") ?? 0

        let fillStr = styles["fill"] ?? attrs["fill"] ?? "#000000"
        let fillColor = parseColor(fillStr) ?? CGColor(gray: 0, alpha: 1)
        let strokeStr = styles["stroke"] ?? attrs["stroke"]
        let strokeColor = (strokeStr != nil && strokeStr != "none")
            ? parseColor(strokeStr!) : nil
        let strokeWidth = Double(styles["stroke-width"] ?? attrs["stroke-width"] ?? "0") ?? 0

        let rect = CGRect(x: x, y: y, width: w, height: h)
        let path: CGPath
        if rx > 0 {
            path = CGPath(roundedRect: rect, cornerWidth: rx, cornerHeight: rx, transform: nil)
        } else {
            path = CGPath(rect: rect, transform: nil)
        }

        var transform = currentTransform
        let transformedPath = path.copy(using: &transform) ?? path

        pathElements.append(PathElement(
            path: transformedPath,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth
        ))
    }

    // MARK: - Text Element

    private func buildTextElement() {
        let content = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let styles = resolveStyles(textAttrs)
        let x = Double(textAttrs["x"] ?? "0") ?? 0
        let y = Double(textAttrs["y"] ?? "0") ?? 0
        let fontSize = Double(styles["font-size"]?.replacingOccurrences(of: "px", with: "") ?? "16") ?? 16
        let fillStr = styles["fill"] ?? textAttrs["fill"] ?? "#000000"
        let fillColor = parseSwiftUIColor(fillStr)
        let anchorStr = textAttrs["text-anchor"] ?? styles["text-anchor"] ?? "start"
        let anchor: UnitPoint = anchorStr == "middle" ? .center : .leading

        textElements.append(TextElement(
            content: content,
            x: x,
            y: y,
            fontSize: fontSize,
            fillColor: fillColor,
            anchor: anchor
        ))
    }

    // MARK: - Style Parsing

    /// Merge inline `style` attribute with direct attributes, style takes precedence.
    private func resolveStyles(_ attrs: [String: String]) -> [String: String] {
        var result: [String: String] = [:]

        // Direct attributes first
        for key in ["fill", "stroke", "stroke-width", "font-size", "font-family", "text-anchor"] {
            if let val = attrs[key] { result[key] = val }
        }

        // Inline style overrides
        if let style = attrs["style"] {
            let pairs = style.split(separator: ";")
            for pair in pairs {
                let kv = pair.split(separator: ":", maxSplits: 1)
                if kv.count == 2 {
                    let key = kv[0].trimmingCharacters(in: .whitespaces)
                    let val = kv[1].trimmingCharacters(in: .whitespaces)
                    result[key] = val
                }
            }
        }

        return result
    }

    /// Parse a CSS color string to CGColor.
    private func parseColor(_ str: String) -> CGColor? {
        let s = str.trimmingCharacters(in: .whitespaces)
        if s == "none" || s.isEmpty { return nil }
        if s.hasPrefix("#") {
            return hexToCGColor(String(s.dropFirst()))
        }
        // Named colors
        switch s.lowercased() {
        case "black": return CGColor(gray: 0, alpha: 1)
        case "white": return CGColor(gray: 1, alpha: 1)
        case "red": return CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        default: return CGColor(gray: 0, alpha: 1)
        }
    }

    private func hexToCGColor(_ hex: String) -> CGColor? {
        var h = hex
        if h.count == 3 {
            h = h.map { "\($0)\($0)" }.joined()
        }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// Parse a CSS color string to SwiftUI Color.
    private func parseSwiftUIColor(_ str: String) -> Color {
        let s = str.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") {
            let hex = String(s.dropFirst())
            var h = hex
            if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
            if let val = UInt64(h, radix: 16) {
                return Color(
                    red: Double((val >> 16) & 0xFF) / 255.0,
                    green: Double((val >> 8) & 0xFF) / 255.0,
                    blue: Double(val & 0xFF) / 255.0
                )
            }
        }
        return .white
    }
}

// MARK: - SVG Path Data Parser

/// Parses SVG path `d` attribute data into a CGPath.
/// Handles: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, T/t, A/a, Z/z
enum SVGPathDataParser {

    static func parse(_ data: String) -> CGPath? {
        var scanner = PathScanner(data)
        let path = CGMutablePath()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint? = nil
        var lastCommand: Character = " "

        while !scanner.isAtEnd {
            scanner.skipWhitespaceAndCommas()
            if scanner.isAtEnd { break }

            guard let cmd = scanner.peekCommand() else {
                // No command letter — repeat previous command
                // (except M becomes L, m becomes l)
                let repeatCmd: Character
                switch lastCommand {
                case "M": repeatCmd = "L"
                case "m": repeatCmd = "l"
                default: repeatCmd = lastCommand
                }
                if !executeCommand(
                    repeatCmd, scanner: &scanner, path: path,
                    current: &current, start: &start,
                    lastControl: &lastControl
                ) { break }
                lastCommand = repeatCmd
                continue
            }

            scanner.advance() // consume the command letter

            if !executeCommand(
                cmd, scanner: &scanner, path: path,
                current: &current, start: &start,
                lastControl: &lastControl
            ) { break }
            lastCommand = cmd
        }

        return path.copy()
    }

    private static func executeCommand(
        _ cmd: Character,
        scanner: inout PathScanner,
        path: CGMutablePath,
        current: inout CGPoint,
        start: inout CGPoint,
        lastControl: inout CGPoint?
    ) -> Bool {
        switch cmd {
        // MoveTo
        case "M":
            guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { return false }
            current = CGPoint(x: x, y: y)
            start = current
            path.move(to: current)
            lastControl = nil
            // Subsequent coordinate pairs are implicit LineTo
            while scanner.hasNumber() {
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                current = CGPoint(x: x, y: y)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        case "m":
            guard let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { return false }
            current = CGPoint(x: current.x + dx, y: current.y + dy)
            start = current
            path.move(to: current)
            lastControl = nil
            while scanner.hasNumber() {
                guard let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                current = CGPoint(x: current.x + dx, y: current.y + dy)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        // LineTo
        case "L":
            while scanner.hasNumber() {
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                current = CGPoint(x: x, y: y)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        case "l":
            while scanner.hasNumber() {
                guard let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                current = CGPoint(x: current.x + dx, y: current.y + dy)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        // Horizontal LineTo
        case "H":
            while scanner.hasNumber() {
                guard let x = scanner.nextNumber() else { break }
                current = CGPoint(x: x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        case "h":
            while scanner.hasNumber() {
                guard let dx = scanner.nextNumber() else { break }
                current = CGPoint(x: current.x + dx, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        // Vertical LineTo
        case "V":
            while scanner.hasNumber() {
                guard let y = scanner.nextNumber() else { break }
                current = CGPoint(x: current.x, y: y)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        case "v":
            while scanner.hasNumber() {
                guard let dy = scanner.nextNumber() else { break }
                current = CGPoint(x: current.x, y: current.y + dy)
                path.addLine(to: current)
                lastControl = nil
            }
            return true

        // Cubic Bezier
        case "C":
            while scanner.hasNumber() {
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                let cp1 = CGPoint(x: x1, y: y1)
                let cp2 = CGPoint(x: x2, y: y2)
                let end = CGPoint(x: x, y: y)
                path.addCurve(to: end, control1: cp1, control2: cp2)
                lastControl = cp2
                current = end
            }
            return true

        case "c":
            while scanner.hasNumber() {
                guard let dx1 = scanner.nextNumber(), let dy1 = scanner.nextNumber(),
                      let dx2 = scanner.nextNumber(), let dy2 = scanner.nextNumber(),
                      let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                let cp1 = CGPoint(x: current.x + dx1, y: current.y + dy1)
                let cp2 = CGPoint(x: current.x + dx2, y: current.y + dy2)
                let end = CGPoint(x: current.x + dx, y: current.y + dy)
                path.addCurve(to: end, control1: cp1, control2: cp2)
                lastControl = cp2
                current = end
            }
            return true

        // Smooth Cubic Bezier
        case "S":
            while scanner.hasNumber() {
                guard let x2 = scanner.nextNumber(), let y2 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                let cp1 = reflectedControl(current: current, lastControl: lastControl)
                let cp2 = CGPoint(x: x2, y: y2)
                let end = CGPoint(x: x, y: y)
                path.addCurve(to: end, control1: cp1, control2: cp2)
                lastControl = cp2
                current = end
            }
            return true

        case "s":
            while scanner.hasNumber() {
                guard let dx2 = scanner.nextNumber(), let dy2 = scanner.nextNumber(),
                      let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                let cp1 = reflectedControl(current: current, lastControl: lastControl)
                let cp2 = CGPoint(x: current.x + dx2, y: current.y + dy2)
                let end = CGPoint(x: current.x + dx, y: current.y + dy)
                path.addCurve(to: end, control1: cp1, control2: cp2)
                lastControl = cp2
                current = end
            }
            return true

        // Quadratic Bezier
        case "Q":
            while scanner.hasNumber() {
                guard let x1 = scanner.nextNumber(), let y1 = scanner.nextNumber(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                let cp = CGPoint(x: x1, y: y1)
                let end = CGPoint(x: x, y: y)
                path.addQuadCurve(to: end, control: cp)
                lastControl = cp
                current = end
            }
            return true

        case "q":
            while scanner.hasNumber() {
                guard let dx1 = scanner.nextNumber(), let dy1 = scanner.nextNumber(),
                      let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                let cp = CGPoint(x: current.x + dx1, y: current.y + dy1)
                let end = CGPoint(x: current.x + dx, y: current.y + dy)
                path.addQuadCurve(to: end, control: cp)
                lastControl = cp
                current = end
            }
            return true

        // Smooth Quadratic Bezier
        case "T":
            while scanner.hasNumber() {
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                let cp = reflectedControl(current: current, lastControl: lastControl)
                let end = CGPoint(x: x, y: y)
                path.addQuadCurve(to: end, control: cp)
                lastControl = cp
                current = end
            }
            return true

        case "t":
            while scanner.hasNumber() {
                guard let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                let cp = reflectedControl(current: current, lastControl: lastControl)
                let end = CGPoint(x: current.x + dx, y: current.y + dy)
                path.addQuadCurve(to: end, control: cp)
                lastControl = cp
                current = end
            }
            return true

        // Elliptical Arc
        case "A":
            while scanner.hasNumber() {
                guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
                      let rotation = scanner.nextNumber(),
                      let largeArc = scanner.nextFlag(),
                      let sweep = scanner.nextFlag(),
                      let x = scanner.nextNumber(), let y = scanner.nextNumber() else { break }
                let end = CGPoint(x: x, y: y)
                addArc(to: path, from: current, to: end,
                       rx: abs(rx), ry: abs(ry),
                       rotation: rotation, largeArc: largeArc, sweep: sweep)
                current = end
                lastControl = nil
            }
            return true

        case "a":
            while scanner.hasNumber() {
                guard let rx = scanner.nextNumber(), let ry = scanner.nextNumber(),
                      let rotation = scanner.nextNumber(),
                      let largeArc = scanner.nextFlag(),
                      let sweep = scanner.nextFlag(),
                      let dx = scanner.nextNumber(), let dy = scanner.nextNumber() else { break }
                let end = CGPoint(x: current.x + dx, y: current.y + dy)
                addArc(to: path, from: current, to: end,
                       rx: abs(rx), ry: abs(ry),
                       rotation: rotation, largeArc: largeArc, sweep: sweep)
                current = end
                lastControl = nil
            }
            return true

        // ClosePath
        case "Z", "z":
            path.closeSubpath()
            current = start
            lastControl = nil
            return true

        default:
            return false
        }
    }

    /// Reflect last control point through current point (for smooth curves).
    private static func reflectedControl(current: CGPoint, lastControl: CGPoint?) -> CGPoint {
        guard let lc = lastControl else { return current }
        return CGPoint(x: 2 * current.x - lc.x, y: 2 * current.y - lc.y)
    }

    // MARK: - Elliptical Arc to Cubic Bezier Conversion

    /// Convert an SVG elliptical arc to cubic bezier curves and add to the path.
    /// Implements the SVG spec endpoint-to-center parameterization conversion.
    private static func addArc(
        to path: CGMutablePath,
        from p1: CGPoint,
        to p2: CGPoint,
        rx inputRx: CGFloat,
        ry inputRy: CGFloat,
        rotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        // Degenerate cases
        if p1 == p2 { return }
        if inputRx == 0 || inputRy == 0 {
            path.addLine(to: p2)
            return
        }

        let phi = rotation * .pi / 180.0
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Step 1: Compute (x1', y1')
        let dx = (p1.x - p2.x) / 2
        let dy = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // Step 2: Ensure radii are large enough
        var rx = inputRx
        var ry = inputRy
        let x1pSq = x1p * x1p
        let y1pSq = y1p * y1p
        let rxSq = rx * rx
        let rySq = ry * ry

        let lambda = x1pSq / rxSq + y1pSq / rySq
        if lambda > 1 {
            let sqrtLambda = sqrt(lambda)
            rx *= sqrtLambda
            ry *= sqrtLambda
        }

        let rxSqNew = rx * rx
        let rySqNew = ry * ry

        // Step 3: Compute center point (cx', cy')
        var num = rxSqNew * rySqNew - rxSqNew * y1pSq - rySqNew * x1pSq
        let den = rxSqNew * y1pSq + rySqNew * x1pSq
        if den == 0 {
            path.addLine(to: p2)
            return
        }
        num = max(num, 0) // Clamp to avoid negative sqrt from floating point
        var sq = sqrt(num / den)
        if largeArc == sweep { sq = -sq }

        let cxp = sq * rx * y1p / ry
        let cyp = -sq * ry * x1p / rx

        // Step 4: Compute center point (cx, cy) in original coordinates
        let mx = (p1.x + p2.x) / 2
        let my = (p1.y + p2.y) / 2
        let cx = cosPhi * cxp - sinPhi * cyp + mx
        let cy = sinPhi * cxp + cosPhi * cyp + my

        // Step 5: Compute start angle and sweep angle
        let ux = (x1p - cxp) / rx
        let uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx
        let vy = (-y1p - cyp) / ry

        let startAngle = vectorAngle(1, 0, ux, uy)
        var sweepAngle = vectorAngle(ux, uy, vx, vy)

        if !sweep && sweepAngle > 0 {
            sweepAngle -= 2 * .pi
        } else if sweep && sweepAngle < 0 {
            sweepAngle += 2 * .pi
        }

        // Step 6: Split into segments and approximate each with a cubic bezier
        let segments = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
        let segmentAngle = sweepAngle / CGFloat(segments)

        for i in 0..<segments {
            let theta1 = startAngle + CGFloat(i) * segmentAngle
            let theta2 = startAngle + CGFloat(i + 1) * segmentAngle
            addArcSegment(
                to: path, cx: cx, cy: cy,
                rx: rx, ry: ry, phi: phi,
                theta1: theta1, theta2: theta2
            )
        }
    }

    /// Add a single arc segment (≤ 90°) as a cubic bezier curve.
    private static func addArcSegment(
        to path: CGMutablePath,
        cx: CGFloat, cy: CGFloat,
        rx: CGFloat, ry: CGFloat,
        phi: CGFloat,
        theta1: CGFloat, theta2: CGFloat
    ) {
        let dTheta = theta2 - theta1
        let t = tan(dTheta / 2)
        let alpha = sin(dTheta) * (sqrt(4 + 3 * t * t) - 1) / 3

        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        func ellipsePoint(_ theta: CGFloat) -> CGPoint {
            let cosT = cos(theta)
            let sinT = sin(theta)
            return CGPoint(
                x: cx + cosPhi * rx * cosT - sinPhi * ry * sinT,
                y: cy + sinPhi * rx * cosT + cosPhi * ry * sinT
            )
        }

        func ellipseDerivative(_ theta: CGFloat) -> CGPoint {
            let cosT = cos(theta)
            let sinT = sin(theta)
            return CGPoint(
                x: -cosPhi * rx * sinT - sinPhi * ry * cosT,
                y: -sinPhi * rx * sinT + cosPhi * ry * cosT
            )
        }

        let p1 = ellipsePoint(theta1)
        let p2 = ellipsePoint(theta2)
        let d1 = ellipseDerivative(theta1)
        let d2 = ellipseDerivative(theta2)

        let cp1 = CGPoint(x: p1.x + alpha * d1.x, y: p1.y + alpha * d1.y)
        let cp2 = CGPoint(x: p2.x - alpha * d2.x, y: p2.y - alpha * d2.y)

        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }

    /// Angle between two vectors in radians.
    private static func vectorAngle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
        var angle = acos(max(-1, min(1, dot / len)))
        if ux * vy - uy * vx < 0 { angle = -angle }
        return angle
    }
}

// MARK: - Path Data Scanner

/// Tokenizer for SVG path data strings.
private struct PathScanner {
    private let chars: [Character]
    private var index: Int

    init(_ string: String) {
        self.chars = Array(string)
        self.index = 0
    }

    var isAtEnd: Bool { index >= chars.count }

    mutating func skipWhitespaceAndCommas() {
        while index < chars.count && (chars[index] == " " || chars[index] == "," ||
              chars[index] == "\n" || chars[index] == "\r" || chars[index] == "\t") {
            index += 1
        }
    }

    /// Peek at the next character to see if it's a command letter.
    func peekCommand() -> Character? {
        var i = index
        while i < chars.count && (chars[i] == " " || chars[i] == "," ||
              chars[i] == "\n" || chars[i] == "\r" || chars[i] == "\t") {
            i += 1
        }
        guard i < chars.count else { return nil }
        let c = chars[i]
        if c.isLetter && c != "e" && c != "E" { return c }
        return nil
    }

    /// Consume a command letter if present.
    mutating func advance() {
        skipWhitespaceAndCommas()
        if index < chars.count { index += 1 }
    }

    /// Check if the next token is a number (for implicit command repetition).
    func hasNumber() -> Bool {
        var i = index
        while i < chars.count && (chars[i] == " " || chars[i] == "," ||
              chars[i] == "\n" || chars[i] == "\r" || chars[i] == "\t") {
            i += 1
        }
        guard i < chars.count else { return false }
        let c = chars[i]
        return c.isNumber || c == "." || c == "-" || c == "+"
    }

    /// Parse the next number from the path data.
    mutating func nextNumber() -> CGFloat? {
        skipWhitespaceAndCommas()
        guard index < chars.count else { return nil }

        var str = ""
        // Optional sign
        if index < chars.count && (chars[index] == "-" || chars[index] == "+") {
            str.append(chars[index])
            index += 1
        }
        // Integer part
        while index < chars.count && chars[index].isNumber {
            str.append(chars[index])
            index += 1
        }
        // Decimal part
        if index < chars.count && chars[index] == "." {
            str.append(chars[index])
            index += 1
            while index < chars.count && chars[index].isNumber {
                str.append(chars[index])
                index += 1
            }
        }
        // Exponent
        if index < chars.count && (chars[index] == "e" || chars[index] == "E") {
            str.append(chars[index])
            index += 1
            if index < chars.count && (chars[index] == "-" || chars[index] == "+") {
                str.append(chars[index])
                index += 1
            }
            while index < chars.count && chars[index].isNumber {
                str.append(chars[index])
                index += 1
            }
        }

        guard !str.isEmpty else { return nil }
        return CGFloat(Double(str) ?? 0)
    }

    /// Parse a flag (0 or 1) for arc commands. Flags can be packed without separators.
    mutating func nextFlag() -> Bool? {
        skipWhitespaceAndCommas()
        guard index < chars.count else { return nil }
        let c = chars[index]
        if c == "0" { index += 1; return false }
        if c == "1" { index += 1; return true }
        return nil
    }
}
