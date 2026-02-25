import SwiftUI

@main
struct DigitFlipApp: App {
    private let encoder: EncoderService?
    private let glyphCache: GlyphCache?
    private let configError: String?

    init() {
        switch GlyphSet.loadLetterMap() {
        case .success(let map):
            let enc = EncoderService(letterMap: map)
            let cache = GlyphCache(glyphSetName: map.glyphSet)
            cache.loadAll(letterMap: map)
            encoder = enc
            glyphCache = cache
            configError = nil
        case .failure(.configurationError(let message)):
            encoder = nil
            glyphCache = nil
            configError = message
        }
    }

    var body: some Scene {
        WindowGroup {
            if let encoder, let glyphCache {
                ContentView(encoder: encoder, glyphCache: glyphCache)
                    .preferredColorScheme(.dark)
            } else {
                ConfigErrorView(message: configError ?? "Unknown error")
                    .preferredColorScheme(.dark)
            }
        }
    }
}
