import XCTest

final class ThemeAdoptionTests: XCTestCase {

    private static let pendingMigration: Set<String> = [
    ]

    private static let colorPattern = try! NSRegularExpression(
        pattern: #"\.(orange|blue|green|red|purple|pink|yellow|gray|teal|indigo|mint|brown|cyan|white|black|primary|secondary|tertiary)\b|Color\(\.system|Color\(\s*red:"#
    )

    private static var viewsDirectory: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "NutriTrack/Views")
    }

    private static func lineNumber(forUTF16Offset offset: Int, in source: String) -> Int {
        let lineFeed = UInt16(UInt8(ascii: "\n"))
        return source.utf16.prefix(offset).filter { $0 == lineFeed }.count + 1
    }

    func testMigratedViewsUseThemeTokens() throws {
        let root = Self.viewsDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path(percentEncoded: false)),
                      "Views directory not found at \(root.path(percentEncoded: false))")

        var offenders: [String] = []

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }

        XCTAssertFalse(files.isEmpty,
                       "Nenhum ficheiro Swift encontrado em \(root.path(percentEncoded: false))")

        for file in files {
            let relative = file.path(percentEncoded: false)
                .replacingOccurrences(of: root.path(percentEncoded: false) + "/", with: "")
            if Self.pendingMigration.contains(relative) { continue }

            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            let matches = Self.colorPattern.matches(in: source, range: range)
            guard !matches.isEmpty else { continue }

            let hits = matches.compactMap { match -> String? in
                guard let hitRange = Range(match.range, in: source) else { return nil }
                let line = Self.lineNumber(forUTF16Offset: match.range.location, in: source)
                return "\(relative):\(line) \(source[hitRange])"
            }
            offenders.append(hits.joined(separator: "\n"))
        }

        XCTAssertTrue(offenders.isEmpty,
                      "Views migradas com cor literal:\n" + offenders.sorted().joined(separator: "\n"))
    }

    func testAllowlistOnlyNamesExistingFiles() throws {
        let root = Self.viewsDirectory
        for entry in Self.pendingMigration {
            let path = root.appending(path: entry)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path(percentEncoded: false)),
                          "Allowlist aponta para ficheiro inexistente: \(entry)")
        }
    }
}
