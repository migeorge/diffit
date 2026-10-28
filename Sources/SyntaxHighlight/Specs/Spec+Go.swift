extension LanguageSpec {
    static let go: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func", "go",
                         "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch",
                         "type", "var"]
        spec.types = ["any", "bool", "byte", "comparable", "complex64", "complex128", "error", "float32", "float64", "int", "int8",
                      "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr"]
        spec.constants = ["true", "false", "nil", "iota"]
        spec.builtins = ["append", "cap", "clear", "close", "complex", "copy", "delete", "imag", "len", "make", "max", "min", "new",
                         "panic", "print", "println", "real", "recover"]
        spec.functionDefiners = ["func"]
        spec.typeDefiners = ["type", "chan"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("\"", interpolation: [Interpolation("%")]),
                        StringStyle("`", escapes: false, multiline: true),
                        StringStyle("'")]
        spec.memberAccess = [pattern(".")]
        spec.typeAfterUnits = [ch("*"), ch("]"), ch("&")]
        spec.declarationTypes = true
        return spec
    }()
}
