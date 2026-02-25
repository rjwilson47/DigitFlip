import SwiftUI

/// Renders a parsed SVG glyph using SwiftUI Canvas.
/// Scales the glyph to fit the bounding box with aspect-fit, centered.
struct SVGGlyphView: View {
    let glyph: ParsedGlyph

    var body: some View {
        Canvas { context, size in
            let vb = glyph.viewBox
            guard vb.width > 0 && vb.height > 0 else { return }

            // Aspect-fit scale
            let scaleX = size.width / vb.width
            let scaleY = size.height / vb.height
            let scale = min(scaleX, scaleY)

            let scaledW = vb.width * scale
            let scaledH = vb.height * scale
            let offsetX = (size.width - scaledW) / 2
            let offsetY = (size.height - scaledH) / 2

            // Apply transform: translate to center, scale, then offset for viewBox origin
            context.translateBy(x: offsetX, y: offsetY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -vb.origin.x, y: -vb.origin.y)

            // Render path elements
            for element in glyph.pathElements {
                let swiftUIPath = Path(element.path)
                context.fill(swiftUIPath, with: .color(Color(cgColor: element.fillColor)))
                if let strokeCG = element.strokeColor, element.strokeWidth > 0 {
                    context.stroke(
                        swiftUIPath,
                        with: .color(Color(cgColor: strokeCG)),
                        lineWidth: element.strokeWidth
                    )
                }
            }

            // Render text elements (placeholders)
            for text in glyph.textElements {
                let resolved = context.resolve(
                    Text(text.content)
                        .font(.system(size: text.fontSize, design: .monospaced))
                        .foregroundColor(text.fillColor)
                )
                let anchor: CGPoint
                if text.anchor == .center {
                    anchor = CGPoint(x: text.x, y: text.y)
                } else {
                    anchor = CGPoint(x: text.x, y: text.y)
                }
                // SVG text y is the baseline; offset up slightly for Canvas draw
                context.draw(
                    resolved,
                    at: anchor,
                    anchor: text.anchor == .center
                        ? UnitPoint(x: 0.5, y: 0.85)
                        : UnitPoint(x: 0, y: 0.85)
                )
            }
        }
    }
}
