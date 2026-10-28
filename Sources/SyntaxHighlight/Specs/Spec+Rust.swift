extension LanguageSpec {
    static let rust: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "fn", "for",
                         "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self",
                         "static", "struct", "super", "trait", "type", "unsafe", "use", "where", "while", "union", "macro_rules"]
        spec.types = ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64", "bool",
                      "char", "str"]
        spec.constants = ["true", "false"]
        spec.functionDefiners = ["fn"]
        spec.typeDefiners = ["struct", "enum", "trait", "type", "union", "impl", "dyn"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.nestedComments = true
        spec.strings = [StringStyle("\"", prefixes: ["r", "br", "cr"], escapes: false, multiline: true, hashes: true),
                        StringStyle("\"", prefixes: ["b", "r", "br", "c", "cr"], multiline: true, interpolation: [.brace]),
                        StringStyle("'", prefixes: ["b"])]
        spec.bracketAttributes = true
        spec.lifetimes = true
        spec.macroBang = true
        spec.memberAccess = [pattern("."), pattern("::")]
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()
}
