import SwiftUI

@main
struct DigitFlipApp: App {
    private let encoder: EncoderService?
    private let configError: String?

    init() {
        switch GlyphSet.loadLetterMap() {
        case .success(let map):
            encoder = EncoderService(letterMap: map)
            configError = nil
        case .failure(.configurationError(let message)):
            encoder = nil
            configError = message
        }
    }

    var body: some Scene {
        WindowGroup {
            if let encoder {
                ContentView(encoder: encoder)
                    .preferredColorScheme(.dark)
            } else {
                ConfigErrorView(message: configError ?? "Unknown error")
                    .preferredColorScheme(.dark)
            }
        }
    }
}
