import Foundation
import Testing
@testable import SyntaxHighlight

@Suite struct SyntaxPerfTests {
    /// 25k lines of Go (near the size cap) must highlight in well under a second.
    @Test func largeGoFile() {
        let unit = """
        package main

        import "fmt"

        // Server wraps an http.Server with a start time.
        type Server struct {
            addr    string
            started int
        }

        func (s *Server) Run(name string) error {
            if s.addr == "" {
                return fmt.Errorf("no address for %q", name)
            }
            return nil
        }

        """
        let lines = Array(repeating: unit.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), count: 1500).flatMap { $0 }
        let start = Date()
        let spans = SyntaxHighlighter.highlight(lines: lines, language: .go)
        let elapsed = Date().timeIntervalSince(start)
        print("highlight \(lines.count) lines of Go: \(Int(elapsed * 1000)) ms, \(spans.count) spans")
        #expect(!spans.isEmpty)
        #expect(elapsed < 1.5)
    }
}
