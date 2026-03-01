import SwiftUI

@main
struct DigitFlipApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            if let encoder = viewModel.encoder, let glyphCache = viewModel.glyphCache {
                ContentView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            } else {
                ConfigErrorView(message: viewModel.configError ?? "Unknown error")
                    .preferredColorScheme(.dark)
            }
        }
    }
}

/// Central app state: manages glyph set discovery, loading, and switching.
@MainActor
final class AppViewModel: ObservableObject {
    @Published var encoder: EncoderService?
    @Published var glyphCache: GlyphCache?
    @Published var configError: String?
    @Published var glyphSetInfos: [GlyphSetInfo] = []
    @Published var selectedGlyphSetID: String = "classic"

    init() {
        glyphSetInfos = GlyphSet.discoverGlyphSets()
        loadGlyphSet("classic")
    }

    func switchGlyphSet(to id: String) {
        guard id != selectedGlyphSetID else { return }
        loadGlyphSet(id)
    }

    private func loadGlyphSet(_ id: String) {
        switch GlyphSet.loadLetterMap(glyphSetName: id) {
        case .success(let map):
            let enc = EncoderService(letterMap: map)
            let cache = GlyphCache(glyphSetName: map.glyphSet)
            cache.preload(letterMap: map)
            encoder = enc
            glyphCache = cache
            configError = nil
            selectedGlyphSetID = id
        case .failure(.configurationError(let message)):
            configError = message
        }
    }
}
