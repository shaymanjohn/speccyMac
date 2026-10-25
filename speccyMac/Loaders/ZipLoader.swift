//
//  ZipLoader.swift
//  speccyMac
//
//  Extracts a loadable game file (.sna/.z80/.tap/.tzx) from a .zip archive.
//  Spectrum games are commonly distributed zipped; this unwraps the archive so
//  the normal extension-based loading path can handle the inner file.
//
//  Uses ZIPFoundation to read the archive in memory and writes the chosen entry
//  to a temporary file, returning its URL (the existing loaders take a URL).
//

import Foundation
import ZIPFoundation

struct ZipLoader {

    /// Extract the first recognised game entry from the zip at `zipURL` to a
    /// temporary file and return its URL, or nil if the archive can't be read
    /// or contains no supported game file.
    static func extractGame(from zipURL: URL) -> URL? {
        guard let archive = try? Archive(url: zipURL, accessMode: .read) else {
            print("ZIP: couldn't open archive \(zipURL.lastPathComponent)")
            return nil
        }

        // Collect file entries whose extension is a supported game type,
        // sorted by path for deterministic selection across multi-game zips.
        // Skip macOS AppleDouble cruft (__MACOSX/ folder and ._ resource-fork
        // stubs), which share the game's extension but aren't the real file.
        let supported = Set(SupportedGameTypes.allCases.map { $0.rawValue })
        let gameEntries = archive
            .filter { $0.type == .file }
            .filter { entry in
                let name = (entry.path as NSString).lastPathComponent
                if entry.path.hasPrefix("__MACOSX/") || name.hasPrefix("._") {
                    return false
                }
                return supported.contains((entry.path as NSString).pathExtension.lowercased())
            }
            .sorted { $0.path < $1.path }

        guard let entry = gameEntries.first else {
            print("ZIP: no supported game file in \(zipURL.lastPathComponent)")
            return nil
        }

        // Extract the entry's bytes in memory.
        var data = Data()
        do {
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
        } catch {
            print("ZIP: failed to extract \(entry.path): \(error)")
            return nil
        }

        // Write to a temp file preserving the inner file's extension so the
        // normal extension dispatch in loadGame picks the right loader.
        let ext = (entry.path as NSString).pathExtension
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        do {
            try data.write(to: tempURL)
        } catch {
            print("ZIP: failed to write temp file: \(error)")
            return nil
        }

        return tempURL
    }
}
