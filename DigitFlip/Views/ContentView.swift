import SwiftUI

// MARK: - Glyph Bounding Box (single constant per spec)

enum GlyphConstants {
    static let glyphWidth: CGFloat = 60
    static let glyphHeight: CGFloat = 80
    static let wordSpacerWidth: CGFloat = 30
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Theme

enum Theme {
    static let background = Color(hex: 0x0a0a0f)
    static let cardBackground = Color(hex: 0x1a1a2e)
    static let accent = Color(hex: 0xe94560)
    static let secondary = Color(hex: 0x0f3460)
    static let inputBackground = Color.white.opacity(0.08)
    static let sectionHeader = Color.gray
    /// Light paper-like background for glyph display areas (ink on paper)
    static let paperBackground = Color(hex: 0xF5F0EB)
}

// MARK: - Config Error View (full-screen, per spec)

struct ConfigErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - Content View (Main Screen)

struct ContentView: View {
    let encoder: EncoderService
    let glyphCache: GlyphCache

    @State private var inputText = ""
    @State private var currentResult: EncodedResult?
    @State private var currentError: String?
    @State private var hasPressed = false
    @FocusState private var isTextFieldFocused: Bool

    // Live validation (runs against lowercased input per spec)
    private var validationError: ValidationError? {
        guard !inputText.isEmpty else { return nil }
        return encoder.validate(inputText)
    }

    private var validationMessage: String? {
        switch validationError {
        case .invalidCharacters:
            return "Invalid characters, use a-z characters only"
        case .characterLimitExceeded:
            return "Character limit exceeded"
        case nil:
            return nil
        }
    }

    // Go disabled when empty/whitespace, or any validation error
    private var isGoDisabled: Bool {
        encoder.isInputEmpty(inputText) || validationError != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("DigitFlip")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 24)
                .padding(.bottom, 4)

            // Input area
            VStack(spacing: 8) {
                TextField("Enter a word or phrase...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .padding(12)
                    .background(Theme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isTextFieldFocused)
                    .onChange(of: inputText) { _, newValue in
                        let lowered = newValue.lowercased()
                        if lowered != newValue {
                            inputText = lowered
                        }
                    }

                // Live inline validation error
                if let message = validationMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Go button
            Button(action: handleGo) {
                Text("Go")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isGoDisabled ? Color.gray.opacity(0.2) : Theme.accent)
                    .foregroundStyle(isGoDisabled ? Color.gray.opacity(0.5) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isGoDisabled)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Output area
            if hasPressed {
                outputArea
                    .transition(.opacity.animation(.easeOut(duration: 0.3)))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .animation(.easeOut(duration: 0.2), value: validationMessage)
    }

    // MARK: - Output Area

    @ViewBuilder
    private var outputArea: some View {
        if let error = currentError {
            // Encoding error (missing mapping — config issue, shown distinctly)
            VStack(spacing: 8) {
                Image(systemName: "wrench.trianglebadge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        } else if let result = currentResult {
            VStack(alignment: .leading, spacing: 20) {
                // Line 1: Write These Numbers
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("Write These Numbers")
                    Text(result.digitDisplay)
                        .font(.system(size: 28, design: .monospaced))
                        .foregroundStyle(.white)
                }

                // Lines 2 & 3: shared ScrollView per spec
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Line 2: Write This
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader("Write This")
                            GlyphRowView(elements: result.elements, glyphCache: glyphCache)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Theme.paperBackground)
                                )
                        }

                        // Line 3: Flipped Preview
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader("Flipped Preview")
                            FlippedGlyphRowView(elements: result.elements, glyphCache: glyphCache)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Theme.paperBackground)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.sectionHeader)
            .tracking(1.2)
    }

    // MARK: - Go Action

    private func handleGo() {
        isTextFieldFocused = false

        let result = encoder.encode(inputText)
        withAnimation(.easeOut(duration: 0.3)) {
            hasPressed = true
            switch result {
            case .success(let encoded):
                currentResult = encoded
                currentError = nil
            case .failure(.missingMapping(let char)):
                currentResult = nil
                currentError = "No mapping found for '\(char)'"
            }
        }
    }
}
