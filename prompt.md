# Claude Code Prompt: DigitFlip — Magician's Number-to-Word Encoder (iOS)

## Project Overview

Build a single-screen SwiftUI iOS app called **DigitFlip** that helps magicians perform a specific trick: writing a sequence of numbers that, when the paper is physically flipped 180°, spells out a word. The app uses custom SVG glyphs — each glyph is a digit (or digit pair) drawn in a special style so that when rotated 180°, it visually resembles a letter.

---

## Core User Flow

1. User types a lowercase word or phrase (a–z, spaces allowed) into a text field.
2. User presses **"Go"**.
3. The app displays three lines of output:
   - **Line 1 — "Write These Numbers":** The digit code for each letter, displayed in **reversed letter order** using standard system font. Codes are treated as **strings, never as integers** — leading zeros must be preserved (e.g., "p" has code `"01"`, which displays as `01`, NOT `1`). Digits from multi-digit letters are shown together (no internal spacing), with a single space separating each letter's code within a word, and a visually wider gap (e.g., triple space or an em-width spacer) separating words. Example: input `"mom"` → letter codes are `41`, `0`, `41` → reversed letter order → display: `41 0 41` (palindrome, so same). Input `"hi"` → codes are `4`, `1` → reversed → display: `1 4`. Input `"hi you"` → reversed letter order is `u, o, y, [space], i, h` → display: `0 0 6   1 4` (wider gap where the word break is). Input `"top"` → codes are `7`, `0`, `01` → reversed → display: `01 0 7` (leading zero on "p" preserved).
   - **Line 2 — "Write This":** The corresponding SVG glyphs rendered in the same reversed letter order as Line 1. This is what the magician physically draws on paper.
   - **Line 3 — "Flipped Preview":** Line 2 rotated 180° as a single unit (both glyph order reversal and individual glyph rotation — identical to physically flipping the paper upside-down). This is what the audience will see.

---

## Letter-to-Code Mapping

Each lowercase letter maps to a one- or two-digit code. Each letter has **exactly one SVG glyph** regardless of how many digits its code contains (multi-digit codes like `41` for "m" are a single SVG containing both digits drawn together).

Below is the full mapping. **Store this as a structured data file** (`letter_map.json`) so it can be edited without touching app code:

```json
{
  "glyphSet": "classic",
  "letters": {
    "a": { "code": "0", "glyphFile": "lowercase_a.svg" },
    "b": { "code": "9", "glyphFile": "lowercase_b.svg" },
    "c": { "code": "0", "glyphFile": "lowercase_c.svg" },
    "d": { "code": "10", "glyphFile": "lowercase_d.svg" },
    "e": { "code": "2", "glyphFile": "lowercase_e.svg" },
    "f": { "code": "3", "glyphFile": "lowercase_f.svg" },
    "g": { "code": "6", "glyphFile": "lowercase_g.svg" },
    "h": { "code": "4", "glyphFile": "lowercase_h.svg" },
    "i": { "code": "1", "glyphFile": "lowercase_i.svg" },
    "j": { "code": "1", "glyphFile": "lowercase_j.svg" },
    "k": { "code": "71", "glyphFile": "lowercase_k.svg" },
    "l": { "code": "1", "glyphFile": "lowercase_l.svg" },
    "m": { "code": "41", "glyphFile": "lowercase_m.svg" },
    "n": { "code": "4", "glyphFile": "lowercase_n.svg" },
    "o": { "code": "0", "glyphFile": "lowercase_o.svg" },
    "p": { "code": "01", "glyphFile": "lowercase_p.svg" },
    "q": { "code": "6", "glyphFile": "lowercase_q.svg" },
    "r": { "code": "7", "glyphFile": "lowercase_r.svg" },
    "s": { "code": "5", "glyphFile": "lowercase_s.svg" },
    "t": { "code": "7", "glyphFile": "lowercase_t.svg" },
    "u": { "code": "0", "glyphFile": "lowercase_u.svg" },
    "v": { "code": "7", "glyphFile": "lowercase_v.svg" },
    "w": { "code": "14", "glyphFile": "lowercase_w.svg" },
    "x": { "code": "7", "glyphFile": "lowercase_x.svg" },
    "y": { "code": "6", "glyphFile": "lowercase_y.svg" },
    "z": { "code": "2", "glyphFile": "lowercase_z.svg" }
  }
}
```

> **IMPORTANT:** Note that multiple letters share the same digit code (e.g., a/c/o/u all = `0`, i/j/l/r all = `1`). This is intentional — each letter has a **unique glyph** that draws that digit differently so it looks like the correct letter when rotated. The codes are not unique identifiers; the glyph files are.

> **CRITICAL — CODES ARE STRINGS, NOT INTEGERS:** The `code` field must be decoded and stored as a `String`, never as an `Int`. Some codes have leading zeros (e.g., `"01"` for "p"). Converting to `Int` and back would produce `"1"`, which is wrong — it changes the digit count, breaks Line 1 display, and misrepresents what the magician should write.

> **NOTE:** These codes may be adjusted as glyph designs are refined. The architecture must make changing these trivial (just edit the JSON).

---

## Glyph Asset Architecture

### Folder Structure
```
DigitFlip/
├── Assets/
│   └── GlyphSets/
│       └── classic/
│           ├── letter_map.json
│           ├── lowercase_a.svg
│           ├── lowercase_b.svg
│           ├── lowercase_c.svg
│           └── ... (one SVG per letter, named lowercase_x.svg)
├── Models/
│   ├── LetterMapping.swift        // Codable struct for letter_map.json
│   └── GlyphSet.swift             // Loads glyph set: documents dir → bundle → placeholder fallback
├── Views/
│   ├── ContentView.swift          // Main screen
│   ├── GlyphRowView.swift         // Renders a horizontal row of SVG glyphs
│   └── FlippedGlyphRowView.swift  // Same row, rotated 180°
├── Services/
│   └── EncoderService.swift       // Text → reversed glyph sequence logic
└── DigitFlipApp.swift
```

### Design Principles
- **Glyphs are SVG files**, not a font. Render using a library that handles SVGs natively (see Technical Requirements for evaluated options and selection guidance). Do NOT convert SVGs to PNGs at build time.
- **Each letter = one SVG file**, even for multi-digit codes. The SVG for "m" contains the artistic rendering of "41" as a single composed image.
- **Glyph sets are self-contained folders.** Each folder has its own `letter_map.json` and its own SVG files. To add a new "font," add a new folder. No code changes required.

### Asset Loading Strategy (Three-Tier Fallback)

The `GlyphSet` loader should resolve each glyph file using this priority order:

1. **Documents directory** (`App Documents/GlyphSets/classic/lowercase_a.svg`) — checked first. This is where future downloadable glyph packs will be installed. Initially this directory won't exist and that's fine; the loader just skips to the next tier.
2. **App bundle** (`Bundle.main` resources, copied into a `GlyphSets/classic/` group) — the default for built-in glyph sets. SVGs are added to the Xcode project as raw resource files (NOT the asset catalog, which doesn't support SVGs natively). This is where your current SVGs live. Dropping a new SVG into the Xcode project folder and rebuilding is all that's needed.
3. **Runtime placeholder** — if neither location has the file, generate a placeholder SVG in memory (see Placeholder SVG Generation below). This means the app is always fully functional even with 0 real SVGs.

This means:
- **Right now:** Just drop SVGs into the Xcode project's `GlyphSets/classic/` bundle group. Simple.
- **Future downloadable packs:** Write downloaded glyph sets to the documents directory. They automatically take priority over bundled assets with no architecture change.
- **Development/testing:** The app works immediately with any number of missing glyphs thanks to the placeholder tier.

The `letter_map.json` follows the same fallback: documents directory → bundle → **full-screen error state** displaying "Could not load glyph configuration. Check letter_map.json." (the JSON is required; unlike individual glyphs, there's no sensible placeholder for the mapping itself). Do NOT use `fatalError()` — it kills the app with no user feedback and looks like a crash. A malformed JSON (missing comma, bad encoding) should also trigger this same error state, not a crash.

- **Placeholder generation:** For any letter that doesn't have a real SVG file in either location, auto-generate a placeholder SVG string in memory (not written to disk), parse it through the same render pipeline as file-based glyphs, and cache the result. The placeholder should display the letter and its digit code so it's obvious which letter it represents (e.g., a rectangle containing "m = 41"). This makes the app fully testable before all art is delivered.

---

## Encoding & Reversal Logic (EncoderService)

```
Input: "hi"

Step 1 — Split into characters: ["h", "i"]
Step 2 — Map to letter entries:
  h → { code: "4", glyph: "lowercase_h.svg" }
  i → { code: "1", glyph: "lowercase_i.svg" }

Step 3 — Reverse the array of entries:
  [i_entry, h_entry]

Step 4 — Output for display:
  Line 1 (digit codes):  "1 4"  (codes joined with spaces, leading zeros preserved as strings)
  Line 2 (glyphs):       [lowercase_i.svg, lowercase_h.svg]  (rendered left to right)
  Line 3 (flipped):      Line 2 with .rotationEffect(.degrees(180)) applied to Line 3's HStack (not the ScrollView or VStack)
```

```
Input: "hi you"

Step 1 — Split into characters: ["h", "i", " ", "y", "o", "u"]
Step 2 — Map to letter entries:
  h → { code: "4", glyph: "lowercase_h.svg" }
  i → { code: "1", glyph: "lowercase_i.svg" }
  " " → space (no glyph, visual gap)
  y → { code: "6", glyph: "lowercase_y.svg" }
  o → { code: "0", glyph: "lowercase_o.svg" }
  u → { code: "0", glyph: "lowercase_u.svg" }

Step 3 — Reverse the entire array of entries:
  [u_entry, o_entry, y_entry, space, i_entry, h_entry]

Step 4 — Output for display:
  Line 1 (digit codes):  "0 0 6   1 4"  (wider gap where the word break is)
  Line 2 (glyphs):       [lowercase_u.svg, lowercase_o.svg, lowercase_y.svg, [gap], lowercase_i.svg, lowercase_h.svg]
  Line 3 (flipped):      Line 2 with .rotationEffect(.degrees(180)) applied to Line 3's HStack (not the ScrollView or VStack)

Verification: magician writes "0 0 6 1 4" left-to-right using custom glyphs.
Audience flips paper 180° → order reverses to "4 1 6 0 0" and each glyph rotates → reads "hi you".
```

**Space handling:** A space in the input should produce a visual gap between glyph groups (use a fixed-width spacer, not a glyph). Spaces are also reversed with the letter order. **Multiple consecutive spaces are preserved** — e.g., `"hi  you"` (two spaces) produces a wider gap than `"hi you"` (one space). Do not collapse multiple spaces into one.

**Empty / whitespace-only input:** The "Go" button should be **disabled** (greyed out, not tappable) when the text field is empty or contains only spaces. No error message needed — the disabled state is self-explanatory.

**Character limit:** Maximum input length is **50 characters**. If the user exceeds this, display an inline error message below the text field: **"Character limit exceeded"**. Do not process the input or show partial results. The text field itself can allow typing beyond 50 (so the user can see what they typed and edit it down), but the Go button should be disabled and the error shown until the input is 50 characters or fewer.

**Validation order:** Input is first auto-lowercased, then validated. This means `"Hello!"` becomes `"hello!"` — the uppercase letters are fine, but the `!` triggers the invalid character error. All validation checks (invalid characters, character limit, empty/whitespace) run against the **lowercased** input.

**Validation priority:** If multiple errors apply simultaneously, show only the first matching: **invalid characters → character limit exceeded**. Do not stack multiple error messages.

**Invalid characters:** If the lowercased input contains any character that is not a lowercase letter (a–z) or a space, display an inline error message below the text field: **"Invalid characters, use a-z characters only"**. Do not process the input or show partial results — the error replaces the output area until the input is corrected.

**Results update on Go press only:** Results are computed and displayed only when the user taps "Go" — not live as the user types. The previous result remains visible while the user edits the text field, and is replaced (or cleared by an error) on the next Go press. Note: the Go button's disabled/enabled state and inline validation errors (invalid characters, character limit) DO update live as the user types — only the results output waits for Go.

**Missing mapping:** If a letter exists in the input but has no entry in `letter_map.json` (e.g., the JSON was edited and a letter was accidentally removed), display: **"No mapping found for '[letter]'"**. This is a configuration error, not a user error — display it distinctly from the invalid character error (e.g., different color or icon). This should not crash the app.

---

## UI Specification (Single Screen)

### Layout (top to bottom)
1. **App title:** "DigitFlip" at the top.
2. **Text input field:** Placeholder text "Enter a word or phrase..." — auto-lowercases any input, then validates (see Validation Order below). Maximum 50 characters.
3. **"Go" button.** Disabled (greyed out) when any validation error is active (empty/whitespace input, character limit exceeded, or invalid characters detected). See validation rules below.
4. **Results area** (visible after pressing Go; **blank in the initial state** before Go has been pressed — no placeholder text or skeleton UI needed):
   - **Section: "Write These Numbers"** — Line 1: the digit codes in reversed letter order, in system font, with space-separated letter groups and wider gaps between words.
   - **Section: "Write This"** — Line 2: horizontal row of SVG glyphs in reversed letter order. **All glyphs are the same width** — render each glyph into a uniform bounding box using aspect-fit scaling, centered on both axes, with a transparent background. Preserve the SVG's viewBox — do not crop or distort. The exact bounding box dimensions (start with 60pt wide × 80pt tall) will be tuned once real art is available; define these as a single constant, not hardcoded in multiple places.
   - **Section: "Flipped Preview"** — Line 3: the exact same glyph row as Line 2, but Line 3's HStack is rotated 180°.
   - **Scrolling:** Both Line 2 and Line 3 are wrapped in a **single `ScrollView`** containing a `VStack` of both rows. This scrolls them together as a unit — no separate scroll containers. The 180° rotation is applied only to Line 3's inner `HStack`, not to the `ScrollView` or `VStack`. This avoids inverted scroll gestures entirely.

> **NOTE — Placeholder glyphs in Flipped Preview:** During development, before real SVG art is available, the Flipped Preview will show upside-down placeholder rectangles with inverted text. This is expected and acceptable — the core flip trick cannot be visually verified until real glyph art that is designed to be legible when rotated is provided. Do NOT attempt to "fix" the placeholders to look correct when flipped; that defeats their purpose as temporary stand-ins.

### Style
- Clean, minimal, dark-themed UI (magician aesthetic).
- Monospaced or clean sans-serif for the digit display (Line 1).
- Results should feel like a "reveal" — consider a subtle animation when Go is pressed.

---

## Technical Requirements

- **Platform:** iOS 17+, SwiftUI
- **SVG rendering (RESEARCH REQUIRED — this is a risk area):** SVGKit is largely unmaintained and has known issues with SPM and modern SwiftUI. Do NOT default to SVGKit without first verifying it works. Evaluate these options in order of preference:
  1. **SwiftSVG** (SPM-compatible, renders SVG to `CAShapeLayer` or `UIBezierPath`) — lightweight, actively maintained, good for simple SVGs.
  2. **Convert SVG → `Path`/`Shape` at load time** — parse the SVG path data and render natively in SwiftUI. Best performance, but only practical if the glyphs are simple paths (no gradients, filters, etc.).
  3. **`WKWebView`-based rendering** — most compatible (handles any SVG), but heavier and harder to size/align precisely in SwiftUI layouts.
  4. **SVGKit** — only as a last resort. If used, pin a specific working version and test thoroughly.
  Choose the approach that reliably renders the actual SVG files provided. The glyphs are likely simple shapes/paths (digits drawn artistically), so options 1 or 2 should work. If the real SVGs turn out to be complex, fall back to option 3.
- **Placeholder rendering pipeline:** Runtime placeholders are generated as SVG strings in memory (not written to disk). The pipeline is: generate SVG string → parse into the same renderable format used for file-based glyphs → cache the result (see caching below). This means file-based glyphs and placeholders go through the same render path — only the source differs (file vs. string).
- **SVG caching:** Parse/render each SVG **once** and cache the result (e.g., as a `UIImage` or rendered `View` snapshot) keyed by glyph filename + glyph set name. Cache is built when a glyph set is loaded and reused across multiple "Go" taps. Invalidate the cache only when the active glyph set changes. Do NOT re-parse SVGs on every render pass.
- **No hardcoded mappings in Swift code.** All letter→code→glyph mappings come from `letter_map.json`. The Swift code should be completely agnostic to which letters exist, what their codes are, or how many digits a code has.
- **Rotation (CRITICAL — this is the crux of the trick):** The 180° flip must be a single `.rotationEffect(.degrees(180))` applied to **Line 3's HStack only** (not the ScrollView, not the VStack container, not individual glyphs). This 2D rotation maps `(x, y) → (-x, -y)`, which simultaneously inverts each glyph AND reverses left-to-right reading order — exactly matching what happens when you physically flip a piece of paper upside-down. Do NOT use `.rotation3DEffect` around X or Y axes, as these produce mirror/flip effects that are NOT equivalent to a physical paper flip.
- **Testability:** Include a unit test target with tests for:
  - Correct encoding of single letters (including letters with multi-digit codes like "m" → "41")
  - Correct encoding of multi-letter words
  - Correct reversal order
  - Space handling: single space preserved, multiple consecutive spaces preserved (not collapsed)
  - Invalid character detection: numbers, punctuation, special characters trigger "Invalid characters, use a-z characters only" error
  - Character limit: inputs over 50 characters trigger "Character limit exceeded" error
  - Empty / whitespace-only input: Go button is disabled, no output produced
  - Missing mapping detection: letter present in input but absent from JSON triggers "No mapping found" error
  - **JSON decoding from bundle:** `letter_map.json` loads correctly from the app bundle; all 26 letters are present; each entry has a non-empty `code` and `glyphFile`
  - **Missing glyph file → placeholder used:** When a glyph file referenced in the JSON doesn't exist on disk, the loader returns a placeholder image (not nil, not a crash)
  - **Code strings preserve leading zeros:** A letter with code `"01"` (e.g., "p") retains the leading zero — it displays as `01`, NOT `1`. Codes are always stored and displayed as strings, never converted to integers. Also verify `"0"` (e.g., "a") is preserved as `"0"`, not `""` or missing

---

## Placeholder SVG Generation

For any letter that doesn't have a real SVG file in either the documents directory or the app bundle (tiers 1 and 2 of the loading strategy), auto-generate a placeholder SVG string in memory and render it through the same parsing/caching pipeline as file-based glyphs (see Technical Requirements). The placeholder should be a simple graphic (e.g., rounded rectangle with the letter and digit code as text inside). This means the app works immediately with 0 real SVGs and gracefully improves as real art is dropped in.

Suggested placeholder format:
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="60" height="80" viewBox="0 0 60 80">
  <rect x="2" y="2" width="56" height="76" rx="8" fill="#1a1a2e" stroke="#e94560" stroke-width="2"/>
  <text x="30" y="35" text-anchor="middle" fill="#e94560" font-size="24" font-family="monospace">m</text>
  <text x="30" y="60" text-anchor="middle" fill="#0f3460" font-size="16" font-family="monospace">41</text>
</svg>
```

---

## Future Considerations (Don't Build Yet, But Architect For)

- **Multiple glyph sets ("fonts"):** A picker screen to switch between `classic/`, `neon/`, etc. The folder-based architecture and three-tier loading already support this — just needs a UI.
- **Downloadable glyph packs:** Download zipped glyph sets from a server, unzip into the documents directory `GlyphSets/` folder. The loader already checks documents directory first, so downloaded packs automatically take priority over bundled defaults.
- **Share/export:** Ability to export the glyph row as an image.
- **Phrase library:** Saved phrases the magician uses frequently.

---

## Summary of What to Build

1. Xcode project with SwiftUI, targeting iOS 17+.
2. `letter_map.json` with the mapping table above.
3. Folder-based glyph set system (`Assets/GlyphSets/classic/`).
4. `EncoderService` that reads the JSON mapping, encodes text to reversed glyph sequences.
5. Single-screen UI with text input (50 char max), Go button (disabled when input is empty/invalid), and three-line output (digits, glyphs, flipped glyphs).
6. SVG rendering for glyph display (see Technical Requirements for evaluated options and selection guidance).
7. Runtime placeholder SVG generation for missing glyphs.
8. 180° rotation applied to Line 3's HStack only. Lines 2 and 3 share a single ScrollView.
9. Error states: invalid characters, character limit exceeded, missing mapping, missing JSON config (full-screen).
10. Unit tests for encoding logic, JSON loading, placeholder fallback, leading zero preservation.
11. Clean, dark-themed magician aesthetic.

**Start with getting the encoding logic and placeholder rendering working end-to-end. Pixel-perfect styling is secondary to correct behavior.**
