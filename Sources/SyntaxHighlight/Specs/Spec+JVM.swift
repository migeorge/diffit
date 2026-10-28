extension LanguageSpec {
    static let java: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["abstract", "assert", "break", "case", "catch", "class", "const", "continue", "default", "do", "else", "enum",
                         "extends", "final", "finally", "for", "goto", "if", "implements", "import", "instanceof", "interface",
                         "native", "new", "package", "private", "protected", "public", "return", "static", "strictfp", "super",
                         "switch", "synchronized", "this", "throw", "throws", "transient", "try", "volatile", "while", "var",
                         "record", "sealed", "permits", "yield", "non-sealed"]
        spec.types = ["boolean", "byte", "char", "short", "int", "long", "float", "double", "void"]
        spec.constants = ["true", "false", "null"]
        spec.typeDefiners = ["class", "interface", "enum", "record", "extends", "implements", "new"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("\"\"\"", multiline: true), StringStyle("\""), StringStyle("'")]
        spec.attributePrefix = pattern("@")
        spec.memberAccess = [pattern(".")]
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()

    static let kotlin: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["as", "break", "class", "continue", "do", "else", "for", "fun", "if", "in", "interface", "is", "object",
                         "package", "return", "super", "this", "throw", "try", "typealias", "typeof", "val", "var", "when", "while",
                         "by", "catch", "constructor", "delegate", "dynamic", "field", "file", "finally", "get", "import", "init",
                         "param", "property", "receiver", "set", "setparam", "value", "where", "abstract", "actual", "annotation",
                         "companion", "const", "crossinline", "data", "enum", "expect", "external", "final", "infix", "inline",
                         "inner", "internal", "lateinit", "noinline", "open", "operator", "out", "override", "private", "protected",
                         "public", "reified", "sealed", "suspend", "tailrec", "vararg", "it"]
        spec.constants = ["true", "false", "null"]
        spec.functionDefiners = ["fun"]
        spec.typeDefiners = ["class", "interface", "object", "enum", "typealias"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.nestedComments = true
        spec.strings = [StringStyle("\"\"\"", escapes: false, multiline: true, interpolation: [.dollarBrace, .dollarName]),
                        StringStyle("\"", interpolation: [.dollarBrace, .dollarName]),
                        StringStyle("'")]
        spec.attributePrefix = pattern("@")
        spec.memberAccess = [pattern("."), pattern("?.")]
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()

    static let scala: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["abstract", "case", "catch", "class", "def", "do", "else", "enum", "export", "extends", "extension", "final",
                         "finally", "for", "forSome", "given", "if", "implicit", "import", "inline", "lazy", "match", "new", "null",
                         "object", "override", "package", "private", "protected", "return", "sealed", "super", "then", "this",
                         "throw", "trait", "try", "type", "using", "val", "var", "while", "with", "yield", "opaque", "open",
                         "transparent", "derives", "end"]
        spec.constants = ["true", "false", "null", "None", "Nil"]
        spec.functionDefiners = ["def"]
        spec.typeDefiners = ["class", "trait", "object", "type", "enum", "extends", "with", "new"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.nestedComments = true
        spec.strings = [StringStyle("\"\"\"", prefixes: ["s", "f", "raw"], escapes: false, multiline: true,
                                    interpolation: [.dollarBrace, .dollarName], interpolationPrefix: "sf"),
                        StringStyle("\"", prefixes: ["s", "f", "raw"], interpolation: [.dollarBrace, .dollarName], interpolationPrefix: "sf"),
                        StringStyle("'")]
        spec.attributePrefix = pattern("@")
        spec.memberAccess = [pattern(".")]
        spec.capitalizedIsType = true
        return spec
    }()
}
