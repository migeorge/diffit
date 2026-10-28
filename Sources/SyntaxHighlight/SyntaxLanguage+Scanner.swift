extension SyntaxLanguage {
    /// The scanner for this language; one instance per language for the life of the process.
    var scanner: any LineScanner {
        Self.scanners[self] ?? CodeScanner(LanguageSpec())
    }

    private static let scanners: [SyntaxLanguage: any LineScanner] =
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.makeScanner()) })

    private func makeScanner() -> any LineScanner {
        switch self {
        case .markdown: return MarkdownScanner()
        case .html: return MarkupScanner(.html)
        case .xml: return MarkupScanner(.xml)
        case .php: return MarkupScanner(.php)
        case .css: return CSSScanner()
        case .yaml: return YAMLScanner()
        case .dockerfile: return DockerfileScanner()
        case .go: return CodeScanner(.go)
        case .python: return CodeScanner(.python)
        case .bash: return CodeScanner(.bash)
        case .fish: return CodeScanner(.fish)
        case .swift: return CodeScanner(.swift)
        case .cpp: return CodeScanner(.cpp)
        case .c: return CodeScanner(.c)
        case .rust: return CodeScanner(.rust)
        case .json: return CodeScanner(.json)
        case .toml: return CodeScanner(.toml)
        case .javascript: return CodeScanner(.javascript)
        case .typescript: return CodeScanner(.typescript)
        case .tsx: return CodeScanner(.tsx)
        case .ruby: return CodeScanner(.ruby)
        case .java: return CodeScanner(.java)
        case .kotlin: return CodeScanner(.kotlin)
        case .lua: return CodeScanner(.lua)
        case .objc: return CodeScanner(.objc)
        case .haskell: return CodeScanner(.haskell)
        case .elixir: return CodeScanner(.elixir)
        case .sql: return CodeScanner(.sql)
        case .scala: return CodeScanner(.scala)
        }
    }
}
