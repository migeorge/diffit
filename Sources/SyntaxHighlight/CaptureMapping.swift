/// Folds tree-sitter capture names onto `TokenKind`. The grammars' own `highlights.scm` files use
/// two naming conventions (tree-sitter's `function.builtin` style and nvim's `keyword.return`,
/// `markup.heading` style); the longest dotted prefix with an entry wins, and a `nil` entry means
/// "plain text" (operators, brackets, ordinary variables).
enum CaptureMapping {
    /// Captures that carry no colour information and must not override one that does.
    private static let ignored: Set<String> = ["spell", "nospell", "conceal"]

    private static let table: [String: TokenKind?] = [
        "keyword": .keyword, "include": .keyword, "conditional": .keyword, "repeat": .keyword,
        "exception": .keyword, "storageclass": .keyword, "directive": .keyword,
        "variable.builtin": .keyword, "boolean": .constant,
        "charset": .keyword, "import": .keyword, "keyframes": .keyword, "media": .keyword,
        "supports": .keyword, "namespace": .type, "module": .type,
        "function": .function, "method": .function, "constructor": .function,
        "function.macro": .attribute, "constant.macro": .attribute, "preproc": .attribute,
        "define": .attribute, "function.special": .attribute,
        "type": .type, "class": .type,
        "string": .string, "character": .string, "string.special.key": .property,
        "string.escape": .escape, "escape": .escape, "character.special": .escape,
        "comment": .comment,
        "number": .number, "float": .number,
        "constant": .constant,
        "property": .property, "field": .property, "variable.member": .property,
        "attribute": .attribute,
        "label": .label,
        "tag": .tag, "tag.error": nil,
        "operator": nil, "punctuation": nil, "delimiter": nil, "variable": nil, "parameter": nil,
        "embedded": nil, "none": nil, "error": nil,
        // Markdown (block and inline grammars use the older `text.*` names).
        "text.title": .heading, "markup.heading": .heading,
        "text.strong": .strong, "markup.strong": .strong, "markup.bold": .strong,
        "text.emphasis": .emphasis, "markup.italic": .emphasis,
        "text.uri": .link, "text.reference": .link, "markup.link": .link,
        "text.literal": .codeSpan, "markup.raw": .codeSpan,
        "markup.list": .keyword, "markup.quote": .comment, "markup": nil,
    ]

    /// `nil` for a capture that should be left as plain text; `.some(nil)` is also "plain", and
    /// callers distinguish "ignored" captures (no opinion) from "plain" ones (an opinion).
    static func kind(for name: String) -> TokenKind?? {
        if name.hasPrefix("_") || ignored.contains(name) { return nil }
        var components = name.split(separator: ".")
        while !components.isEmpty {
            if let entry = table[components.joined(separator: ".")] { return .some(entry) }
            components.removeLast()
        }
        return .some(nil)
    }
}
