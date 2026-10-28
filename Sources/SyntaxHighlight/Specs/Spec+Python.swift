extension LanguageSpec {
    static let python: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else", "except",
                         "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass",
                         "raise", "return", "try", "while", "with", "yield", "self", "cls"]
        spec.lineStartKeywords = ["match", "case"]
        spec.types = ["int", "float", "complex", "str", "bytes", "bytearray", "bool", "list", "dict", "set", "frozenset", "tuple",
                      "object", "type", "range", "memoryview", "slice"]
        spec.constants = ["True", "False", "None", "Ellipsis", "NotImplemented"]
        spec.builtins = ["abs", "all", "any", "ascii", "bin", "breakpoint", "callable", "chr", "classmethod", "compile", "delattr",
                         "dir", "divmod", "enumerate", "eval", "exec", "filter", "format", "getattr", "globals", "hasattr", "hash",
                         "help", "hex", "id", "input", "isinstance", "issubclass", "iter", "len", "locals", "map", "max", "min",
                         "next", "oct", "open", "ord", "pow", "print", "property", "repr", "reversed", "round", "setattr", "sorted",
                         "staticmethod", "sum", "super", "vars", "zip", "__import__"]
        spec.functionDefiners = ["def"]
        spec.typeDefiners = ["class"]
        spec.lineComments = [pattern("#")]
        let prefixes: Set<String> = ["f", "r", "b", "u", "t", "rb", "br", "fr", "rf", "rt", "tr"]
        spec.strings = [StringStyle("\"\"\"", prefixes: prefixes, multiline: true, interpolation: [.brace], interpolationPrefix: "ft"),
                        StringStyle("'''", prefixes: prefixes, multiline: true, interpolation: [.brace], interpolationPrefix: "ft"),
                        StringStyle("\"", prefixes: prefixes, interpolation: [.brace], interpolationPrefix: "ft"),
                        StringStyle("'", prefixes: prefixes, interpolation: [.brace], interpolationPrefix: "ft")]
        spec.attributePrefix = pattern("@")
        spec.memberAccess = [pattern(".")]
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()
}
