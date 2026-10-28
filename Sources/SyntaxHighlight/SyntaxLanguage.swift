import Foundation

/// A language with a bundled tree-sitter grammar.
public enum SyntaxLanguage: String, CaseIterable, Sendable {
    case go, python, bash, fish, markdown, swift, cpp, c, rust
    case json, yaml, toml, javascript, typescript, tsx, html, css, ruby, java, kotlin, lua
    case dockerfile, objc, haskell, elixir, sql, php, scala, xml

    public var displayName: String {
        switch self {
        case .go: return "Go"
        case .python: return "Python"
        case .bash: return "Shell"
        case .fish: return "fish"
        case .markdown: return "Markdown"
        case .swift: return "Swift"
        case .cpp: return "C++"
        case .c: return "C"
        case .rust: return "Rust"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .tsx: return "TSX"
        case .html: return "HTML"
        case .css: return "CSS"
        case .ruby: return "Ruby"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .lua: return "Lua"
        case .dockerfile: return "Dockerfile"
        case .objc: return "Objective-C"
        case .haskell: return "Haskell"
        case .elixir: return "Elixir"
        case .sql: return "SQL"
        case .php: return "PHP"
        case .scala: return "Scala"
        case .xml: return "XML"
        }
    }

    // MARK: - Detection

    /// Picks a language from the file name, falling back to a `#!` line for extensionless scripts.
    public static func detect(path: String, firstLine: String? = nil) -> SyntaxLanguage? {
        let name = (path as NSString).lastPathComponent
        if let language = byFileName[name] ?? byFileName[name.lowercased()] { return language }
        let ext = (name as NSString).pathExtension.lowercased()
        if !ext.isEmpty, let language = byExtension[ext] { return language }
        if let firstLine, firstLine.hasPrefix("#!") { return fromShebang(firstLine) }
        return nil
    }

    private static func fromShebang(_ line: String) -> SyntaxLanguage? {
        // "#!/usr/bin/env python3", "#!/bin/bash -e", "#!/usr/local/bin/fish"
        let words = line.dropFirst(2).split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard var interpreter = words.first.map({ ($0 as NSString).lastPathComponent }) else { return nil }
        if interpreter == "env", words.count > 1 { interpreter = (words[1] as NSString).lastPathComponent }
        interpreter = interpreter.lowercased()
        let stem = interpreter.prefix { !$0.isNumber && $0 != "." }
        switch stem {
        case "bash", "sh", "zsh", "ksh", "dash": return .bash
        case "fish": return .fish
        case "python": return .python
        case "ruby": return .ruby
        case "node", "deno", "bun": return .javascript
        case "lua": return .lua
        case "php": return .php
        case "elixir": return .elixir
        case "swift": return .swift
        default: return nil
        }
    }

    private static let byExtension: [String: SyntaxLanguage] = [
        "go": .go,
        "py": .python, "pyi": .python, "pyw": .python,
        "sh": .bash, "bash": .bash, "zsh": .bash, "ksh": .bash,
        "fish": .fish,
        "md": .markdown, "markdown": .markdown, "mdown": .markdown, "mkd": .markdown,
        "swift": .swift,
        "cpp": .cpp, "cc": .cpp, "cxx": .cpp, "c++": .cpp, "hpp": .cpp, "hh": .cpp, "hxx": .cpp,
        "h++": .cpp, "ino": .cpp, "ipp": .cpp,
        "c": .c, "h": .c,
        "rs": .rust,
        "json": .json, "jsonc": .json, "webmanifest": .json, "geojson": .json,
        "yml": .yaml, "yaml": .yaml,
        "toml": .toml,
        "js": .javascript, "mjs": .javascript, "cjs": .javascript, "jsx": .javascript,
        "ts": .typescript, "mts": .typescript, "cts": .typescript,
        "tsx": .tsx,
        "html": .html, "htm": .html, "xhtml": .html,
        "css": .css,
        "rb": .ruby, "rake": .ruby, "gemspec": .ruby, "ru": .ruby,
        "java": .java,
        "kt": .kotlin, "kts": .kotlin,
        "lua": .lua,
        "dockerfile": .dockerfile,
        "m": .objc, "mm": .objc,
        "hs": .haskell,
        "ex": .elixir, "exs": .elixir,
        "sql": .sql,
        "php": .php, "phtml": .php,
        "scala": .scala, "sc": .scala, "sbt": .scala,
        "xml": .xml, "plist": .xml, "xsd": .xml, "xsl": .xml, "xslt": .xml, "svg": .xml,
        "xib": .xml, "storyboard": .xml, "entitlements": .xml, "xcscheme": .xml, "xcprivacy": .xml,
    ]

    private static let byFileName: [String: SyntaxLanguage] = [
        "Dockerfile": .dockerfile, "Containerfile": .dockerfile,
        "Gemfile": .ruby, "Rakefile": .ruby, "Podfile": .ruby, "Fastfile": .ruby, "Brewfile": .ruby,
        "Cargo.lock": .toml, "Package.resolved": .json,
        ".bashrc": .bash, ".bash_profile": .bash, ".bash_aliases": .bash, ".profile": .bash,
        ".zshrc": .bash, ".zshenv": .bash, ".zprofile": .bash,
    ]
}
