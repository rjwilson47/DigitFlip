import Foundation

/// A single letter's entry in the glyph mapping.
struct LetterEntry: Codable, Equatable {
    /// The digit code displayed for this letter (e.g., "41" for "m", "01" for "p").
    /// Always a String — never convert to Int, as leading zeros must be preserved.
    let code: String
    /// The SVG filename for this letter (e.g., "m.svg").
    let glyphFile: String
}

/// The top-level structure of letter_map.json.
struct LetterMap: Codable, Equatable {
    /// The name of this glyph set (e.g., "classic").
    let glyphSet: String
    /// Mapping from lowercase letter (single character) to its entry.
    let letters: [String: LetterEntry]
}
