import SwiftUI

@main
struct DigitFlipApp: App {
    @State private var encoder: EncoderService?
    @State private var glyphCache: GlyphCache?
    @State private var configError: String?
    @State private var glyphSetInfos: [GlyphSetInfo] = []
    @State private var selectedGlyphSetID: String = "classic"

    init() {
        let infos = GlyphSet.discoverGlyphSets()
        _glyphSetInfos = State(initialValue: infos)

        switch GlyphSet.loadLetterMap() {
        case .success(let map):
            let enc = EncoderService(letterMap: map)
            let cache = GlyphCache(glyphSetName: map.glyphSet)
            cache.loadAll(letterMap: map)
            _encoder = State(initialValue: enc)
            _glyphCache = State(initialValue: cache)
            _configError = State(initialValue: nil)
            _selectedGlyphSetID = State(initialValue: map.glyphSet)
        case .failure(.configurationError(let message)):
            _encoder = State(initialValue: nil)
            _glyphCache = State(initialValue: nil)
            _configError = State(initialValue: message)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let encoder, let glyphCache {
                ContentView(
                    encoder: encoder,
                    glyphCache: glyphCache,
                    glyphSetInfos: glyphSetInfos,
                    selectedGlyphSetID: $selectedGlyphSetID,
                    onGlyphSetChanged: switchGlyphSet
                )
                .preferredColorScheme(.dark)
            } else {
                ConfigErrorView(message: configError ?? "Unknown error")
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func switchGlyphSet(to id: String) {
        switch GlyphSet.loadLetterMap(glyphSetName: id) {
        case .success(let map):
            let enc = EncoderService(letterMap: map)
            let cache = GlyphCache(glyphSetName: map.glyphSet)
            cache.loadAll(letterMap: map)
            encoder = enc
            glyphCache = cache
            configError = nil
            selectedGlyphSetID = id
        case .failure(.configurationError(let message)):
            configError = message
        }
    }
}
