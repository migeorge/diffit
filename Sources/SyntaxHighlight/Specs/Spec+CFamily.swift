extension LanguageSpec {
    private static let cKeywords: Set<String> = ["auto", "break", "case", "const", "continue", "default", "do", "else", "enum",
        "extern", "for", "goto", "if", "inline", "register", "restrict", "return", "sizeof", "static", "struct", "switch", "typedef",
        "union", "volatile", "while", "_Atomic", "_Static_assert", "_Thread_local", "_Alignas", "_Alignof", "_Generic", "_Noreturn",
        "alignas", "alignof", "static_assert", "thread_local", "typeof", "__attribute__", "__asm__", "asm"]
    private static let cTypes: Set<String> = ["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "bool",
        "_Bool", "size_t", "ssize_t", "ptrdiff_t", "intptr_t", "uintptr_t", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t",
        "uint16_t", "uint32_t", "uint64_t", "FILE", "va_list", "wchar_t", "off_t", "pid_t", "time_t"]

    private static func cFamily() -> LanguageSpec {
        var spec = LanguageSpec()
        spec.keywords = cKeywords
        spec.types = cTypes
        spec.constants = ["NULL", "true", "false"]
        spec.typeDefiners = ["struct", "union", "enum"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("\"", prefixes: ["l", "u", "u8"]), StringStyle("'", prefixes: ["l", "u", "u8"])]
        spec.preprocessor = .lineStart
        spec.memberAccess = [pattern("."), pattern("->")]
        spec.upperCaseIsConstant = true
        spec.typeSuffixes = ["_t"]
        spec.callsBeforeTypes = true
        return spec
    }

    static let c = cFamily()

    static let cpp: LanguageSpec = {
        var spec = cFamily()
        spec.keywords.formUnion(["and", "and_eq", "bitand", "bitor", "catch", "class", "compl", "concept", "consteval", "constexpr",
                                 "constinit", "const_cast", "co_await", "co_return", "co_yield", "decltype", "delete", "dynamic_cast",
                                 "explicit", "export", "friend", "module", "mutable", "namespace", "new", "noexcept", "not", "not_eq",
                                 "nullptr", "operator", "or", "or_eq", "override", "final", "private", "protected", "public",
                                 "reinterpret_cast", "requires", "static_cast", "template", "this", "throw", "try", "typeid",
                                 "typename", "using", "virtual", "xor", "xor_eq", "import"])
        spec.types.formUnion(["string", "wstring", "string_view", "vector", "map", "set", "unordered_map", "unordered_set", "list",
                              "deque", "array", "pair", "tuple", "optional", "variant", "shared_ptr", "unique_ptr", "weak_ptr",
                              "function", "span", "any", "byte"])
        spec.constants.insert("nullptr")
        spec.typeDefiners.formUnion(["class", "typename", "namespace"])
        spec.memberAccess.append(pattern("::"))
        spec.capitalizedIsType = true
        return spec
    }()

    static let objc: LanguageSpec = {
        var spec = cFamily()
        spec.keywords.formUnion(["@interface", "@implementation", "@end", "@protocol", "@property", "@synthesize", "@dynamic",
                                 "@class", "@selector", "@encode", "@try", "@catch", "@finally", "@throw", "@synchronized",
                                 "@autoreleasepool", "@optional", "@required", "@public", "@private", "@protected", "@package",
                                 "@import", "@available", "@compatibility_alias", "@defs", "self", "super", "in", "out", "inout",
                                 "bycopy", "byref", "oneway", "nonatomic", "atomic", "strong", "weak", "copy", "assign", "retain",
                                 "readonly", "readwrite", "nonnull", "nullable", "null_resettable", "unsafe_unretained", "getter",
                                 "setter", "IBOutlet", "IBAction", "__block", "__weak", "__strong", "__bridge", "__kindof",
                                 "instancetype", "id"])
        spec.types.formUnion(["BOOL", "SEL", "IMP", "Class", "NSInteger", "NSUInteger", "CGFloat"])
        spec.constants.formUnion(["nil", "Nil", "YES", "NO"])
        spec.strings.insert(StringStyle("@\"", "\""), at: 0)
        spec.attributePrefix = pattern("@")
        spec.capitalizedIsType = true
        spec.typeSuffixes.append("Ref")
        return spec
    }()
}
