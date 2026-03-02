import Foundation

/// A single letter's entry in the glyph mapping.
struct LetterEntry: Codable, Equatable {
    /// The digit code displayed for this letter (e.g., "41" for "m", "01" for "p").
    /// Always a String — never convert to Int, as leading zeros must be preserved.
    let code: String
    /// The SVG filename for this letter (e.g., "lowercase_m.svg").
    let glyphFile: String
}

/// The top-level structure of letter_map.json.
struct LetterMap: Codable, Equatable {
    /// The name of this glyph set (e.g., "classic").
    let glyphSet: String
    /// Human-readable display name for UI (e.g., "Digitext").
    let displayName: String
    /// Availability status: "available" or "coming_soon".
    let status: String
    /// Symbols shown in the frequency counter (e.g., ["0"..."9"] or ["0"..."9","J","Q","K"]).
    /// Optional in JSON — defaults to digits 0-9 if omitted.
    let symbols: [String]?
    /// Mapping from lowercase letter (single character) to its entry.
    let letters: [String: LetterEntry]

    /// The symbols to display in the frequency counter, with a default fallback.
    var frequencySymbols: [String] {
        symbols ?? ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    }
}

/// Lightweight metadata for populating the glyph set picker without loading all letter entries.
struct GlyphSetInfo: Identifiable, Equatable {
    /// The folder name / internal identifier (e.g., "classic", "card_deck").
    let glyphSet: String
    /// Human-readable name shown in the picker (e.g., "Digitext").
    let displayName: String
    /// Availability status: "available" or "coming_soon".
    let status: String

    var id: String { glyphSet }
    var isAvailable: Bool { status == "available" }
}
