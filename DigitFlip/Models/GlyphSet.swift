import Foundation

/// Handles loading glyph set configuration and resolving glyph files
/// using the three-tier fallback: documents directory → bundle → placeholder.
struct GlyphSet {

    enum LoadError: Error, Equatable {
        case configurationError(String)
    }

    // MARK: - Glyph Set Discovery

    /// Discover all glyph sets by scanning bundle subfolders of GlyphSets/.
    /// Returns metadata for each set (for the picker UI), sorted with available sets first.
    static func discoverGlyphSets(bundle: Bundle = .main) -> [GlyphSetInfo] {
        guard let glyphSetsURL = bundle.resourceURL?.appendingPathComponent("GlyphSets") else {
            return []
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: glyphSetsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        var infos: [GlyphSetInfo] = []
        for folderURL in contents {
            guard (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            let jsonURL = folderURL.appendingPathComponent("letter_map.json")
            guard let data = try? Data(contentsOf: jsonURL) else { continue }

            // Decode just the top-level metadata without parsing all letter entries
            struct MetadataOnly: Decodable {
                let glyphSet: String
                let displayName: String
                let status: String
            }
            guard let meta = try? JSONDecoder().decode(MetadataOnly.self, from: data) else { continue }
            infos.append(GlyphSetInfo(
                glyphSet: meta.glyphSet,
                displayName: meta.displayName,
                status: meta.status
            ))
        }

        // Sort: available first, then by display name
        return infos.sorted { a, b in
            if a.isAvailable != b.isAvailable { return a.isAvailable }
            return a.displayName < b.displayName
        }
    }

    // MARK: - Letter Map Loading

    /// Load letter_map.json using the three-tier fallback.
    /// - Parameters:
    ///   - glyphSetName: The glyph set folder name (default: "classic").
    ///   - documentsDirectory: Optional documents directory URL (tier 1).
    ///   - bundle: The bundle to search (tier 2). Defaults to `.main`.
    /// - Returns: A loaded `LetterMap` or a `LoadError`.
    static func loadLetterMap(
        glyphSetName: String = "classic",
        documentsDirectory: URL? = nil,
        bundle: Bundle = .main
    ) -> Result<LetterMap, LoadError> {
        // Tier 1: Documents directory
        if let docsDir = documentsDirectory {
            let docsPath = docsDir
                .appendingPathComponent("GlyphSets")
                .appendingPathComponent(glyphSetName)
                .appendingPathComponent("letter_map.json")
            if let data = try? Data(contentsOf: docsPath),
               let map = try? JSONDecoder().decode(LetterMap.self, from: data) {
                return .success(map)
            }
        }

        // Tier 2: Bundle
        if let bundleURL = bundle.url(
            forResource: "letter_map",
            withExtension: "json",
            subdirectory: "GlyphSets/\(glyphSetName)"
        ) {
            do {
                let data = try Data(contentsOf: bundleURL)
                let map = try JSONDecoder().decode(LetterMap.self, from: data)
                return .success(map)
            } catch {
                return .failure(.configurationError(
                    "Could not load glyph configuration. Check letter_map.json."
                ))
            }
        }

        // No JSON found at all
        return .failure(.configurationError(
            "Could not load glyph configuration. Check letter_map.json."
        ))
    }

    /// Decode a `LetterMap` directly from JSON data.
    /// Useful for testing or loading from arbitrary sources.
    static func decodeLetterMap(from data: Data) -> Result<LetterMap, LoadError> {
        do {
            let map = try JSONDecoder().decode(LetterMap.self, from: data)
            return .success(map)
        } catch {
            return .failure(.configurationError(
                "Could not load glyph configuration. Check letter_map.json."
            ))
        }
    }

    // MARK: - Glyph File Resolution

    /// Check whether a glyph file exists on disk (tier 1 or tier 2).
    static func glyphFileExists(
        fileName: String,
        glyphSetName: String = "classic",
        documentsDirectory: URL? = nil,
        bundle: Bundle = .main
    ) -> Bool {
        // Tier 1: Documents directory
        if let docsDir = documentsDirectory {
            let path = docsDir
                .appendingPathComponent("GlyphSets")
                .appendingPathComponent(glyphSetName)
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                return true
            }
        }

        // Tier 2: Bundle
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        if bundle.url(
            forResource: nameWithoutExt,
            withExtension: ext,
            subdirectory: "GlyphSets/\(glyphSetName)"
        ) != nil {
            return true
        }

        return false
    }

    /// Resolve a glyph file's URL from tier 1 or tier 2, or return `nil` if not found
    /// (caller should fall back to a placeholder).
    static func resolveGlyphFileURL(
        fileName: String,
        glyphSetName: String = "classic",
        documentsDirectory: URL? = nil,
        bundle: Bundle = .main
    ) -> URL? {
        // Tier 1: Documents directory
        if let docsDir = documentsDirectory {
            let path = docsDir
                .appendingPathComponent("GlyphSets")
                .appendingPathComponent(glyphSetName)
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // Tier 2: Bundle
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return bundle.url(
            forResource: nameWithoutExt,
            withExtension: ext,
            subdirectory: "GlyphSets/\(glyphSetName)"
        )
    }

    // MARK: - Placeholder SVG Generation

    /// Generate a placeholder SVG string for a letter that has no real glyph file.
    /// The placeholder shows the letter and its digit code so it's obvious which letter it represents.
    static func placeholderSVG(letter: String, code: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="60" height="80" viewBox="0 0 60 80">
          <rect x="2" y="2" width="56" height="76" rx="8" fill="#1a1a2e" stroke="#e94560" stroke-width="2"/>
          <text x="30" y="35" text-anchor="middle" fill="#e94560" font-size="24" font-family="monospace">\(letter)</text>
          <text x="30" y="60" text-anchor="middle" fill="#0f3460" font-size="16" font-family="monospace">\(code)</text>
        </svg>
        """
    }
}
