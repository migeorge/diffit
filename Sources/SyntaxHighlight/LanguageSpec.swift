/// A string literal form: delimiters, escapes and what gets highlighted inside it.
struct StringStyle {
    var open: Pattern
    var close: Pattern
    /// Letters allowed right before `open` (Python `f`, `rb`; Rust `b`; C++ `L`, `u8`).
    var prefixes: Set<String> = []
    var escapes = true
    var multiline = false
    /// Raw strings whose delimiters carry a matching run of `#`: Swift `#"…"#`, Rust `r#"…"#`.
    var hashes = false
    var interpolation: [Interpolation] = []
    /// Interpolation only applies when the prefix contains this letter (Python `f`, Scala `s`).
    var interpolationPrefix: String?
    var kind: TokenKind = .string

    init(_ open: String, _ close: String? = nil, prefixes: Set<String> = [], escapes: Bool = true, multiline: Bool = false,
         hashes: Bool = false, interpolation: [Interpolation] = [], interpolationPrefix: String? = nil, kind: TokenKind = .string) {
        self.open = pattern(open)
        self.close = pattern(close ?? open)
        self.prefixes = prefixes
        self.escapes = escapes
        self.multiline = multiline
        self.hashes = hashes
        self.interpolation = interpolation
        self.interpolationPrefix = interpolationPrefix
        self.kind = kind
    }
}

/// An interpolation inside a string, painted as `.escape`: `$name` (no `close`), `${…}`, `\(…)`, `#{…}`.
struct Interpolation {
    var open: Pattern
    var close: Pattern?

    init(_ open: String, _ close: String? = nil) {
        self.open = pattern(open)
        self.close = close.map(pattern)
    }

    static let dollarBrace = Interpolation("${", "}")
    static let dollarName = Interpolation("$")
    static let hashBrace = Interpolation("#{", "}")
    static let backslashParen = Interpolation("\\(", ")")
    static let brace = Interpolation("{", "}")
}

enum Preprocessor { case none, lineStart, anywhere }

enum HeredocStyle { case shell, ruby, php }

/// The table that drives `CodeScanner` for one language.
struct LanguageSpec {
    var keywords: Set<String> = []
    /// Keywords only when first on the line (Python's `match`, Dockerfile instructions).
    var lineStartKeywords: Set<String> = []
    var types: Set<String> = []
    var constants: Set<String> = []
    /// Built-in functions and commands, coloured as functions.
    var builtins: Set<String> = []
    /// Keywords whose following word is a function name (`func`, `def`, `fn`).
    var functionDefiners: Set<String> = []
    /// Keywords whose following word is a type name (`struct`, `class`, `type`).
    var typeDefiners: Set<String> = []
    var caseInsensitive = false

    var lineComments: [Pattern] = []
    /// The comment marker only counts at the start of a word (shells: `$#` is a variable).
    var commentNeedsBoundary = false
    var blockComment: (open: Pattern, close: Pattern)?
    var nestedComments = false
    /// Checked before comments: Haskell `{-# … #-}` pragmas.
    var pragma: (open: Pattern, close: Pattern)?

    var strings: [StringStyle] = []
    /// Extra units allowed inside identifiers (`-` in Lisp-style names, `?`/`!` in Ruby, `'` in Haskell).
    var identifierExtra: Set<UInt16> = []
    /// `$name`, `@name`, `${…}` → property.
    var variablePrefixes: [Pattern] = []
    /// Specials allowed after a variable prefix (`$?`, `$#`, `$1`).
    var variableSpecials: Set<UInt16> = []
    /// `@name` → attribute (keywords such as `@interface` win).
    var attributePrefix: Pattern?
    /// Rust/PHP `#[…]` attributes.
    var bracketAttributes = false
    var preprocessor: Preprocessor = .none

    var capitalizedIsType = false
    var upperCaseIsConstant = false
    var typeSuffixes: [String] = []
    /// A capitalised identifier right after one of these units is a type (Go: `*T`, `[]T`, `&T`).
    var typeAfterUnits: Set<UInt16> = []
    /// Go-style `name Type` declarations: a capitalised word after a plain identifier is a type.
    var declarationTypes = false
    var callIsFunction = true
    /// C family: `NSLog(`, `CreateWindow(` are calls even though capitalised.
    var callsBeforeTypes = false
    /// Rust: `name!(` is a macro, coloured as an attribute.
    var macroBang = false
    /// Member access operators; a word after one is a property unless called.
    var memberAccess: [Pattern] = []
    /// A word or string followed by this is a key (JSON `:`, TOML `=`).
    var keyMarker: Pattern?
    /// `[section]` lines are headers (TOML).
    var sectionHeaders = false
    var regexLiterals = false
    var jsxTags = false
    var lifetimes = false
    /// Elixir `~r/…/` sigils.
    var sigils = false
    /// Ruby/Elixir `:atom` → constant.
    var symbols = false
    var heredocs: HeredocStyle?
    /// Shells: the first word of a command is coloured as a function.
    var commandPosition = false
    /// Keywords after which the next word is again a command (`if`, `then`, `do`, fish `and`).
    var commandTriggers: Set<String> = []
    /// Commands after which the next word is again a command (`sudo`, `exec`, `time`).
    var commandWrappers: Set<String> = []
    /// Shell `NAME=value`: the name is a property.
    var assignmentIsProperty = false
    /// Haskell: an unindented lowercase word that starts a line is a function definition.
    var lineStartFunctions = false
    /// Extra units kept inside a number (TOML dates: `-`, `:`).
    var numberExtra: Set<UInt16> = []
}
