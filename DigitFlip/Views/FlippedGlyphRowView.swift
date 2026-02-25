import SwiftUI

/// Line 3's glyph row — identical to GlyphRowView but with 180° rotation
/// applied to the HStack. This simulates physically flipping the paper upside-down:
/// the 2D rotation maps (x,y) → (-x,-y), which both inverts each glyph
/// and reverses left-to-right reading order.
///
/// Per spec: use `.rotationEffect(.degrees(180))`, NOT `.rotation3DEffect`.
struct FlippedGlyphRowView: View {
    let elements: [EncodedElement]
    let glyphCache: GlyphCache

    var body: some View {
        GlyphRowView(elements: elements, glyphCache: glyphCache)
            .rotationEffect(.degrees(180))
    }
}
