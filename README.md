# DigitFlip

A single-screen iOS app that helps magicians perform a number-to-word reveal trick. The magician writes a sequence of numbers on paper, and when the paper is flipped 180°, the numbers transform into a readable word or phrase.

<img width="1206" height="2622" alt="image" src="https://github.com/user-attachments/assets/c45372f6-c77e-4296-87bf-84af16537114" />

## How It Works

Each letter of the alphabet has a custom glyph — a digit (or pair of digits) drawn so that when rotated 180°, it visually resembles a letter. The app handles the encoding so the magician knows exactly what to write.

1. Type a word or phrase (a–z, spaces allowed)
2. Tap **Go**
3. The app shows:
   - **Write These Numbers** — the digit codes to write, in the correct (reversed) order
   - **Write This** — the actual glyphs to copy onto paper
   - **Flipped Preview** — what the audience sees when the paper is flipped upside-down

<img width="1206" height="2622" alt="image" src="https://github.com/user-attachments/assets/7b3bc0f4-235c-4c58-9678-7dd9ee421bfb" />

## Digitexts

The app supports multiple glyph sets ("digitexts"), each with its own visual style for the digit-letter glyphs. A picker at the top of the screen lets you switch between them.

| Digitext | Description | Status |
|----------|-------------|--------|
| Digitext | The default glyph set | Available |
| Digitext without 0 | Alternative glyphs that avoid the digit 0 | Coming Soon |

## Requirements

- iOS 17+
- Xcode 15+

## Building

Open `DigitFlip.xcodeproj` in Xcode and build for a simulator or device. No external dependencies or package managers required — SVG rendering is handled natively.

## Project Structure

```
DigitFlip/
├── DigitFlipApp.swift              # App entry point, glyph set discovery & state
├── Models/
│   ├── LetterMapping.swift         # LetterMap, LetterEntry, GlyphSetInfo structs
│   └── GlyphSet.swift              # Three-tier loading, discovery, placeholder generation
├── Services/
│   ├── EncoderService.swift        # Text → reversed glyph sequence logic
│   └── SVGRenderer.swift           # SVG parsing, GlyphCache
├── Views/
│   ├── ContentView.swift           # Main screen, digitext picker, input & output
│   ├── GlyphRowView.swift          # Horizontal row of SVG glyphs
│   └── FlippedGlyphRowView.swift   # Same row, rotated 180°
└── Resources/
    └── GlyphSets/
        ├── classic/                # Default digitext
        │   ├── letter_map.json
        │   └── lowercase_*.svg
        └── no_zero/                # Coming soon digitext
            ├── letter_map.json
            └── no_zero_lowercase_*.svg
```

## Adding a New Digitext

No code changes required. The app discovers glyph sets automatically at runtime.

1. Create a new folder under `DigitFlip/Resources/GlyphSets/` (e.g., `my_set/`)
2. Add a `letter_map.json` with the mapping for all 26 letters:
   ```json
   {
     "glyphSet": "my_set",
     "displayName": "My Custom Set",
     "status": "available",
     "letters": {
       "a": { "code": "0", "glyphFile": "my_set_lowercase_a.svg" },
       ...
     }
   }
   ```
3. Add 26 SVG glyph files matching the filenames in your JSON
4. Mirror the SVGs to `assets/glyphs/my_set/` (source copies)
5. Build and run — the new set appears in the picker

Set `"status": "coming_soon"` to show the set greyed out in the picker until it's ready.

## Architecture Notes

- **Glyph loading** uses a three-tier fallback: documents directory → app bundle → runtime placeholder. This means the app works even with zero real SVGs (placeholders show the letter and its code).
- **Codes are strings, not integers.** `"01"` for "p" must never be converted to `Int` — leading zeros are significant.
- **All mappings live in JSON** (`letter_map.json`), not in Swift code. Changing a code or glyph filename is a JSON edit, not a code change.
- **SVGs are parsed once and cached** per glyph set. The cache invalidates when switching digitexts.

## License

All rights reserved.
