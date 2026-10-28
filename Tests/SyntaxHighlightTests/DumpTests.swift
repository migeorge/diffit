import Foundation
import Testing
@testable import SyntaxHighlight

/// Scratch: `SYNTAX_DUMP=/path/a.go:/path/b.md swift test --filter DumpTests` prints rendered files.
@Suite struct DumpTests {
    @Test func dump() throws {
        guard let paths = ProcessInfo.processInfo.environment["SYNTAX_DUMP"] else { return }
        for path in paths.split(separator: ":").map(String.init) {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            let lines = text.components(separatedBy: "\n")
            let language = SyntaxLanguage.detect(path: path, firstLine: lines.first)
            print("==== \(path) [\(language?.displayName ?? "plain")]")
            if let language { print(Render.lines(lines, language).joined(separator: "\n")) }
        }
    }
}
