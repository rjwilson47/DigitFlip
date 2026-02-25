import Foundation

// MARK: - Validation Errors

/// Errors arising from user input validation (checked live as the user types).
enum ValidationError: Error, Equatable {
    case invalidCharacters
    case characterLimitExceeded
}

// MARK: - Encoding Errors

/// Errors arising during encoding (configuration issues, not user errors).
enum MappingError: Error, Equatable {
    case missingMapping(Character)
}

// MARK: - Encoded Output Types

/// A single encoded letter with its code and glyph reference.
struct EncodedEntry: Equatable {
    let letter: Character
    let code: String
    let glyphFile: String
}

/// An element in the encoded sequence — either a letter or a space (word boundary).
enum EncodedElement: Equatable {
    case letter(EncodedEntry)
    case space
}

/// The result of encoding an input phrase, containing the reversed element sequence.
struct EncodedResult: Equatable {
    /// Elements in reversed letter order (ready for display).
    let elements: [EncodedElement]

    /// Line 1 display string: digit codes with single space between letters
    /// within a word, and triple space between words. Leading zeros are preserved.
    var digitDisplay: String {
        var result = ""
        var prevWasLetter = false

        for element in elements {
            switch element {
            case .letter(let entry):
                if prevWasLetter {
                    result += " "
                }
                result += entry.code
                prevWasLetter = true
            case .space:
                result += "   "
                prevWasLetter = false
            }
        }

        return result
    }

    /// The glyph file names in display order.
    var glyphFiles: [String?] {
        elements.map { element in
            switch element {
            case .letter(let entry): return entry.glyphFile
            case .space: return nil
            }
        }
    }
}

// MARK: - EncoderService

/// Handles text-to-reversed-glyph-sequence encoding per the DigitFlip spec.
/// All letter→code→glyph mappings come from the provided `LetterMap`.
struct EncoderService {

    static let maxInputLength = 50

    let letterMap: LetterMap

    init(letterMap: LetterMap) {
        self.letterMap = letterMap
    }

    // MARK: - Validation

    /// Validate user input (run against lowercased input).
    /// Returns the first applicable error per priority order:
    /// 1. Invalid characters (anything not a-z or space)
    /// 2. Character limit exceeded (> 50 chars)
    /// Returns `nil` if input is valid.
    func validate(_ input: String) -> ValidationError? {
        let lowered = input.lowercased()

        // Priority 1: invalid characters
        for char in lowered {
            if char != " " && !(char >= "a" && char <= "z") {
                return .invalidCharacters
            }
        }

        // Priority 2: character limit
        if lowered.count > Self.maxInputLength {
            return .characterLimitExceeded
        }

        return nil
    }

    /// Whether the Go button should be disabled (empty/whitespace-only input).
    func isInputEmpty(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Encoding

    /// Encode the input into a reversed glyph sequence.
    /// The input is lowercased, split into characters, mapped to entries, then reversed.
    /// Assumes validation has already passed (call `validate` first).
    func encode(_ input: String) -> Result<EncodedResult, MappingError> {
        let lowered = input.lowercased()

        var elements: [EncodedElement] = []
        for char in lowered {
            if char == " " {
                elements.append(.space)
            } else {
                guard let entry = letterMap.letters[String(char)] else {
                    return .failure(.missingMapping(char))
                }
                elements.append(.letter(EncodedEntry(
                    letter: char,
                    code: entry.code,
                    glyphFile: entry.glyphFile
                )))
            }
        }

        elements.reverse()

        return .success(EncodedResult(elements: elements))
    }
}
