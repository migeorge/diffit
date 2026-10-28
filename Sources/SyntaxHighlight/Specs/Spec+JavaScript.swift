extension LanguageSpec {
    static let javascript: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete",
                         "do", "else", "export", "extends", "finally", "for", "from", "function", "get", "if", "import", "in",
                         "instanceof", "let", "new", "of", "return", "set", "static", "super", "switch", "this", "throw", "try",
                         "typeof", "var", "void", "while", "with", "yield", "as"]
        spec.constants = ["true", "false", "null", "undefined", "NaN", "Infinity"]
        spec.builtins = ["require", "parseInt", "parseFloat", "isNaN", "isFinite", "fetch", "setTimeout", "setInterval",
                         "clearTimeout", "clearInterval", "alert", "structuredClone", "queueMicrotask"]
        spec.functionDefiners = ["function"]
        spec.typeDefiners = ["class", "extends"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("`", multiline: true, interpolation: [.dollarBrace]), StringStyle("\""), StringStyle("'")]
        spec.attributePrefix = pattern("@")
        spec.memberAccess = [pattern("."), pattern("?.")]
        spec.regexLiterals = true
        spec.jsxTags = true
        spec.upperCaseIsConstant = true
        return spec
    }()

    static let typescript: LanguageSpec = {
        var spec = javascript
        spec.keywords.formUnion(["abstract", "declare", "enum", "implements", "interface", "is", "keyof", "module", "namespace",
                                 "type", "private", "protected", "public", "readonly", "override", "satisfies", "infer", "unique",
                                 "asserts", "out", "accessor", "constructor"])
        spec.types = ["any", "boolean", "number", "string", "symbol", "bigint", "void", "never", "unknown", "object"]
        spec.typeDefiners.formUnion(["interface", "type", "enum", "implements", "namespace"])
        spec.capitalizedIsType = true
        spec.jsxTags = false
        return spec
    }()

    static let tsx: LanguageSpec = {
        var spec = typescript
        spec.jsxTags = true
        return spec
    }()
}
