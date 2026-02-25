import SwiftUI

// MARK: - Glyph Row View

/// Renders a horizontal row of SVG glyphs for the encoded elements.
/// Uses GlyphCache to render real SVGs or placeholders through the same pipeline.
struct GlyphRowView: View {
    let elements: [EncodedElement]
    let glyphCache: GlyphCache

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                switch element {
                case .letter(let entry):
                    if let parsed = glyphCache.glyph(
                        forLetter: String(entry.letter),
                        code: entry.code,
                        glyphFile: entry.glyphFile
                    ) {
                        SVGGlyphView(glyph: parsed)
                            .frame(
                                width: GlyphConstants.glyphWidth,
                                height: GlyphConstants.glyphHeight
                            )
                    } else {
                        // Ultimate fallback: simple SwiftUI placeholder
                        PlaceholderGlyphView(
                            letter: String(entry.letter),
                            code: entry.code
                        )
                        .frame(
                            width: GlyphConstants.glyphWidth,
                            height: GlyphConstants.glyphHeight
                        )
                    }
                case .space:
                    Color.clear
                        .frame(
                            width: GlyphConstants.wordSpacerWidth,
                            height: GlyphConstants.glyphHeight
                        )
                }
            }
        }
    }
}

// MARK: - Placeholder Glyph View (ultimate fallback if SVG parsing fails)

/// Fallback placeholder shown only if SVG parsing fails entirely.
struct PlaceholderGlyphView: View {
    let letter: String
    let code: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.cardBackground)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.accent, lineWidth: 2)
            VStack(spacing: 2) {
                Text(letter)
                    .font(.system(size: 22, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }
}
