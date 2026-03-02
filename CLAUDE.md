# DigitFlip — Development Notes

## Multiple digitexts (glyph sets)

The app supports multiple glyph sets ("digitexts"), discovered at runtime by scanning `GlyphSets/` subfolders in the app bundle. Each subfolder is a self-contained digitext with its own `letter_map.json` and SVG files.

**Current sets:**

| Folder | Display Name | Status | SVG prefix |
|--------|-------------|--------|------------|
| `classic/` | Digitext | available | `lowercase_` |
| `card_deck/` | Digitext for card decks (without zero) | available | `card_deck_lowercase_` |

**`letter_map.json` schema** (each set has one):
```json
{
  "glyphSet": "<folder_name>",
  "displayName": "<UI display name>",
  "status": "available" | "coming_soon",
  "symbols": ["0", "1", ...],
  "letters": { ... }
}
```

The `symbols` array defines which symbols appear in the frequency counter at the bottom of the screen. For classic this is `["0"..."9"]`; for card_deck it includes `["0"..."9","J","Q","K"]`. The field is optional in JSON — if omitted, defaults to digits 0-9.

**Adding a new digitext:** Create a new subfolder under `DigitFlip/Resources/GlyphSets/` and `assets/glyphs/` with its own `letter_map.json` and 26 SVG files. Add the folder to the Xcode project. No code changes needed — the app discovers it automatically.

## Mapping changes (letter_map.json)

Each glyph set has its own `letter_map.json` in `DigitFlip/Resources/GlyphSets/<set>/letter_map.json`. If you change letter codes or glyph filenames in the **classic** set, you **must** also update the embedded JSON copies in these test files:

- `DigitFlipTests/EncoderServiceTests.swift`
- `DigitFlipTests/LetterMappingTests.swift` (contains the full mapping **twice** — in two separate test methods)

Keep `prompt.md` in sync too (the JSON block in the "Letter-to-Code Mapping" section and the encoding walkthrough examples below it).

## Codes are strings, not integers

Codes like `"01"` (for classic "p") must stay as strings. Never convert to `Int` — it drops leading zeros and breaks the display. Codes can also contain card values like `"J"`, `"Q"`, `"K"` (used by the card_deck set).

## SVG naming convention

Each glyph set uses its own SVG naming pattern:
- **classic:** `lowercase_x.svg` (e.g., `lowercase_a.svg`)
- **card_deck:** `card_deck_lowercase_x.svg` (e.g., `card_deck_lowercase_a.svg`)

The filenames in `letter_map.json` must match the actual files on disk.

## Glyph file locations

Each glyph set has files in two locations:
- **Source copy:** `assets/glyphs/<set>/` — the raw SVG files
- **App bundle copy:** `DigitFlip/Resources/GlyphSets/<set>/` — what the app actually loads

Both directories should contain the same SVG files for each set.

## Frequency counter (symbols)

The digit frequency counter at the bottom of the output is data-driven. Each `letter_map.json` can specify a `"symbols"` array that controls which columns appear. The `LetterMap.frequencySymbols` computed property provides a default of `["0"..."9"]` if the field is omitted. The counter uses `symbolFrequency` (a `[String: Int]` dictionary) and `highUseSymbols` on `EncodedResult`.

## Keeping this file current

If you make changes that affect the mapping logic, file structure, naming conventions, multi-digitext architecture, or cross-file dependencies described above, update this file to reflect the new state.
