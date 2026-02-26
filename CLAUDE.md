# DigitFlip — Development Notes

## Mapping changes (letter_map.json)

The letter-to-code-to-glyph mapping lives in `DigitFlip/Resources/GlyphSets/classic/letter_map.json`. If you change letter codes or glyph filenames there, you **must** also update the embedded JSON copies in these test files:

- `DigitFlipTests/EncoderServiceTests.swift`
- `DigitFlipTests/LetterMappingTests.swift` (contains the full mapping **twice** — in two separate test methods)

Keep `prompt.md` in sync too (the JSON block in the "Letter-to-Code Mapping" section and the encoding walkthrough examples below it).

## SVG naming convention

SVG glyph files use the pattern `lowercase_x.svg` (e.g., `lowercase_a.svg`, `lowercase_m.svg`). This applies to both the filenames on disk and the `glyphFile` values in `letter_map.json`.

## Codes are strings, not integers

Codes like `"01"` (for "p") must stay as strings. Never convert to `Int` — it drops leading zeros and breaks the display.

## Glyph file locations

- **Source copy:** `assets/glyphs/classic/` — the raw SVG files
- **App bundle copy:** `DigitFlip/Resources/GlyphSets/classic/` — what the app actually loads

Both directories should contain the same SVG files.

## Keeping this file current

If you make changes that affect the mapping logic, file structure, naming conventions, or cross-file dependencies described above, update this file to reflect the new state.
