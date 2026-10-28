import Foundation
import SwiftTreeSitter
import TreeSitterGo
import TreeSitterPython
import TreeSitterBash
import TreeSitterFish
import TreeSitterMarkdown
import TreeSitterMarkdownInline
import TreeSitterSwift
import TreeSitterCPP
import TreeSitterC
import TreeSitterRust
import TreeSitterJSON
import TreeSitterYAML
import TreeSitterTOML
import TreeSitterJavaScript
import TreeSitterTypeScript
import TreeSitterTSX
import TreeSitterHTML
import TreeSitterCSS
import TreeSitterRuby
import TreeSitterJava
import TreeSitterKotlin
import TreeSitterLua
import TreeSitterDockerfile
import TreeSitterObjc
import TreeSitterHaskell
import TreeSitterElixir
import TreeSitterSql
import TreeSitterPHP
import TreeSitterScala
import TreeSitterXML

/// A grammar plus its highlight query source.
struct Grammar {
    let language: Language
    let queryText: String
    /// A grammar for a sub-language parsed inside ranges of this one (Markdown inline).
    let inline: InlineGrammar?

    struct InlineGrammar {
        let language: Language
        let queryText: String
    }

    init(_ pointer: OpaquePointer, query: String, inline: InlineGrammar? = nil) {
        language = Language(language: pointer)
        queryText = query
        self.inline = inline
    }
}

extension SyntaxLanguage {
    var grammar: Grammar {
        switch self {
        case .go: return Grammar(tree_sitter_go(), query: HighlightQueries.go)
        case .python: return Grammar(tree_sitter_python(), query: HighlightQueries.python)
        case .bash: return Grammar(tree_sitter_bash(), query: HighlightQueries.bash)
        case .fish: return Grammar(tree_sitter_fish(), query: HighlightQueries.fish)
        case .markdown:
            let inline = Grammar.InlineGrammar(language: Language(language: tree_sitter_markdown_inline()),
                                               queryText: HighlightQueries.markdownInline)
            return Grammar(tree_sitter_markdown(), query: HighlightQueries.markdown, inline: inline)
        case .swift: return Grammar(tree_sitter_swift(), query: HighlightQueries.swift)
        case .cpp: return Grammar(tree_sitter_cpp(), query: HighlightQueries.cpp)
        case .c: return Grammar(tree_sitter_c(), query: HighlightQueries.c)
        case .rust: return Grammar(tree_sitter_rust(), query: HighlightQueries.rust)
        case .json: return Grammar(tree_sitter_json(), query: HighlightQueries.json)
        case .yaml: return Grammar(tree_sitter_yaml(), query: HighlightQueries.yaml)
        case .toml: return Grammar(tree_sitter_toml(), query: HighlightQueries.toml)
        case .javascript: return Grammar(tree_sitter_javascript(), query: HighlightQueries.javascript)
        case .typescript: return Grammar(tree_sitter_typescript(), query: HighlightQueries.typescript)
        case .tsx: return Grammar(tree_sitter_tsx(), query: HighlightQueries.typescript)
        case .html: return Grammar(tree_sitter_html(), query: HighlightQueries.html)
        case .css: return Grammar(tree_sitter_css(), query: HighlightQueries.css)
        case .ruby: return Grammar(tree_sitter_ruby(), query: HighlightQueries.ruby)
        case .java: return Grammar(tree_sitter_java(), query: HighlightQueries.java)
        case .kotlin: return Grammar(tree_sitter_kotlin(), query: HighlightQueries.kotlin)
        case .lua: return Grammar(tree_sitter_lua(), query: HighlightQueries.lua)
        case .dockerfile: return Grammar(tree_sitter_dockerfile(), query: HighlightQueries.dockerfile)
        case .objc: return Grammar(tree_sitter_objc(), query: HighlightQueries.objc)
        case .haskell: return Grammar(tree_sitter_haskell(), query: HighlightQueries.haskell)
        case .elixir: return Grammar(tree_sitter_elixir(), query: HighlightQueries.elixir)
        case .sql: return Grammar(tree_sitter_sql(), query: HighlightQueries.sql)
        case .php: return Grammar(tree_sitter_php(), query: HighlightQueries.php)
        case .scala: return Grammar(tree_sitter_scala(), query: HighlightQueries.scala)
        case .xml: return Grammar(tree_sitter_xml(), query: HighlightQueries.xml)
        }
    }
}
