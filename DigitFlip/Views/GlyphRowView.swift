import SwiftUI

// MARK: - Glyph Row View

/// Renders a horizontal row of glyph views for the encoded elements.
/// Letters are rendered as placeholder glyphs; spaces become fixed-width gaps.
struct GlyphRowView: View {
    let elements: [EncodedElement]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                switch element {
                case .letter(let entry):
                    PlaceholderGlyphView(
                        letter: String(entry.letter),
                        code: entry.code
                    )
                    .frame(
                        width: GlyphConstants.glyphWidth,
                        height: GlyphConstants.glyphHeight
                    )
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

// MARK: - Placeholder Glyph View

/// A temporary placeholder for a single glyph, showing the letter and its digit code
/// in a styled rounded rectangle. Will be replaced by SVG rendering in a later phase.
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
