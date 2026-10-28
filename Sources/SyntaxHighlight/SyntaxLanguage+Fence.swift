extension SyntaxLanguage {
    /// The language named by a Markdown fence info string (`go`, `py`, `sh`, `c++`…).
    init?(fenceInfo: String) {
        let name = fenceInfo.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "{" }).first.map { String($0).lowercased() } ?? ""
        guard !name.isEmpty else { return nil }
        if let language = Self.fenceNames[name] { self = language; return }
        if let language = Self.detect(path: "x.\(name)") { self = language; return }
        return nil
    }

    private static let fenceNames: [String: SyntaxLanguage] = [
        "golang": .go, "python3": .python, "shell": .bash, "console": .bash, "zsh": .bash, "shell-script": .bash,
        "c++": .cpp, "objective-c": .objc, "objectivec": .objc, "docker": .dockerfile, "javascript": .javascript,
        "typescript": .typescript, "jsx": .javascript, "yml": .yaml, "plist": .xml, "html": .html, "markdown": .markdown,
        "swift": .swift, "rust": .rust, "ruby": .ruby, "java": .java, "kotlin": .kotlin, "lua": .lua, "haskell": .haskell,
        "elixir": .elixir, "sql": .sql, "php": .php, "scala": .scala, "json": .json, "toml": .toml, "css": .css, "scss": .css,
        "fish": .fish, "go": .go, "python": .python, "bash": .bash, "sh": .bash, "c": .c, "cpp": .cpp, "xml": .xml,
        "dockerfile": .dockerfile, "tsx": .tsx, "md": .markdown,
    ]
}
