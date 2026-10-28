extension LanguageSpec {
    static let swift: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout",
                         "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public", "rethrows",
                         "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue", "default",
                         "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw", "switch",
                         "where", "while", "Any", "as", "await", "async", "is", "self", "Self", "super", "throws", "try", "actor",
                         "isolated", "nonisolated", "some", "any", "consuming", "borrowing", "macro", "package", "sending", "each",
                         "convenience", "dynamic", "final", "indirect", "lazy", "mutating", "nonmutating", "optional", "override",
                         "required", "unowned", "weak", "willSet", "didSet", "get", "set", "prefix", "postfix", "infix"]
        spec.constants = ["true", "false", "nil"]
        spec.functionDefiners = ["func"]
        spec.typeDefiners = ["class", "struct", "enum", "protocol", "extension", "typealias", "actor", "associatedtype"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.nestedComments = true
        spec.strings = [StringStyle("\"\"\"", multiline: true, interpolation: [.backslashParen]),
                        StringStyle("\"", escapes: false, hashes: true),
                        StringStyle("\"", interpolation: [.backslashParen])]
        spec.attributePrefix = pattern("@")
        spec.preprocessor = .anywhere
        spec.memberAccess = [pattern(".")]
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()
}
