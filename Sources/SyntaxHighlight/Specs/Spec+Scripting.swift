extension LanguageSpec {
    static let ruby: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["alias", "and", "begin", "BEGIN", "break", "case", "class", "def", "defined?", "do", "else", "elsif", "end",
                         "END", "ensure", "for", "if", "in", "module", "next", "not", "or", "redo", "rescue", "retry", "return",
                         "self", "super", "then", "undef", "unless", "until", "when", "while", "yield", "__FILE__", "__LINE__",
                         "__method__", "__dir__"]
        spec.constants = ["true", "false", "nil"]
        spec.builtins = ["puts", "print", "p", "pp", "require", "require_relative", "attr_accessor", "attr_reader", "attr_writer",
                         "include", "extend", "prepend", "private", "public", "protected", "module_function", "raise", "lambda",
                         "proc", "loop", "catch", "throw", "format", "sprintf", "printf", "gets", "block_given?", "new", "freeze",
                         "define_method", "instance_variable_get", "instance_variable_set", "send", "respond_to?", "is_a?", "nil?",
                         "each", "map", "select", "reject", "reduce", "inject", "to_s", "to_i", "to_a", "to_h", "to_sym", "length",
                         "size", "empty?", "any?", "all?", "none?", "first", "last", "push", "pop", "join", "split", "strip", "gsub",
                         "sub", "match", "scan", "chomp", "chars", "sort", "sort_by", "uniq", "flatten", "compact", "zip", "times",
                         "upto", "downto", "step", "tap", "then", "dig", "fetch", "key?", "keys", "values", "merge", "delete"]
        spec.functionDefiners = ["def"]
        spec.typeDefiners = ["class", "module"]
        spec.lineComments = [pattern("#")]
        spec.blockComment = (pattern("=begin"), pattern("=end"))
        spec.strings = [StringStyle("\"", multiline: true, interpolation: [.hashBrace]),
                        StringStyle("'", escapes: false, multiline: true),
                        StringStyle("`", interpolation: [.hashBrace]),
                        StringStyle("%w[", "]", escapes: false), StringStyle("%w(", ")", escapes: false),
                        StringStyle("%i[", "]", escapes: false), StringStyle("%i(", ")", escapes: false),
                        StringStyle("%q(", ")", escapes: false), StringStyle("%Q(", ")", interpolation: [.hashBrace]),
                        StringStyle("%(", ")", interpolation: [.hashBrace])]
        spec.identifierExtra = [ch("?"), ch("!")]
        spec.variablePrefixes = [pattern("@@"), pattern("@"), pattern("$")]
        spec.variableSpecials = [ch("!"), ch("@"), ch("$"), ch("?"), ch("~"), ch("*"), ch("&"), ch(";"), ch(":"), ch("/"), ch("\\"),
                                 ch("<"), ch(">"), ch(",")]
        spec.symbols = true
        spec.regexLiterals = true
        spec.heredocs = .ruby
        spec.keyMarker = pattern(":")
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()

    static let lua: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in", "local", "not", "or",
                         "repeat", "return", "then", "until", "while", "self"]
        spec.constants = ["true", "false", "nil"]
        spec.builtins = ["print", "require", "pairs", "ipairs", "type", "tostring", "tonumber", "setmetatable", "getmetatable",
                         "pcall", "xpcall", "error", "assert", "select", "rawget", "rawset", "rawequal", "rawlen", "next", "unpack",
                         "load", "loadstring", "dofile", "collectgarbage", "module"]
        spec.functionDefiners = ["function"]
        spec.lineComments = [pattern("--")]
        spec.blockComment = (pattern("--[["), pattern("]]"))
        spec.strings = [StringStyle("[[", "]]", escapes: false, multiline: true), StringStyle("\""), StringStyle("'")]
        spec.memberAccess = [pattern("."), pattern(":")]
        spec.upperCaseIsConstant = true
        return spec
    }()

    static let elixir: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["def", "defp", "defmodule", "defmacro", "defmacrop", "defstruct", "defimpl", "defprotocol", "defguard",
                         "defguardp", "defdelegate", "defexception", "defoverridable", "do", "end", "if", "else", "unless", "case",
                         "cond", "when", "fn", "with", "receive", "after", "rescue", "try", "catch", "raise", "reraise", "throw",
                         "import", "alias", "require", "use", "quote", "unquote", "unquote_splicing", "and", "or", "not", "in",
                         "super", "__MODULE__", "__DIR__", "__ENV__", "__CALLER__", "for", "else"]
        spec.constants = ["true", "false", "nil"]
        spec.builtins = ["puts", "inspect", "send", "spawn", "spawn_link", "self", "is_atom", "is_binary", "is_list", "is_map",
                         "is_nil", "is_integer", "is_float", "is_function", "is_tuple", "is_pid", "is_boolean", "is_number",
                         "length", "hd", "tl", "elem", "div", "rem", "abs", "apply", "make_ref", "node", "put_elem", "round",
                         "trunc", "tuple_size", "map_size", "binary_part", "bit_size", "byte_size", "exit", "to_string",
                         "to_charlist", "put_in", "get_in", "update_in", "struct", "match?", "sigil_r", "sigil_s", "sigil_w"]
        spec.functionDefiners = ["def", "defp", "defmacro", "defmacrop", "defguard", "defguardp", "defdelegate"]
        spec.typeDefiners = ["defmodule", "defprotocol", "defimpl", "alias", "import", "use", "require"]
        spec.lineComments = [pattern("#")]
        spec.strings = [StringStyle("\"\"\"", multiline: true, interpolation: [.hashBrace]),
                        StringStyle("\"", multiline: true, interpolation: [.hashBrace]),
                        StringStyle("'", multiline: true)]
        spec.identifierExtra = [ch("?"), ch("!")]
        spec.attributePrefix = pattern("@")
        spec.sigils = true
        spec.symbols = true
        spec.keyMarker = pattern(":")
        spec.capitalizedIsType = true
        return spec
    }()

    static let haskell: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["case", "class", "data", "default", "deriving", "do", "else", "family", "forall", "foreign", "hiding", "if",
                         "import", "in", "infix", "infixl", "infixr", "instance", "let", "module", "newtype", "of", "qualified",
                         "then", "type", "where", "mdo", "rec", "proc", "as", "pattern", "stock", "anyclass", "via"]
        spec.typeDefiners = ["data", "type", "newtype", "class", "instance", "module", "import", "qualified"]
        spec.lineComments = [pattern("--")]
        spec.blockComment = (pattern("{-"), pattern("-}"))
        spec.nestedComments = true
        spec.pragma = (pattern("{-#"), pattern("#-}"))
        spec.strings = [StringStyle("\"", multiline: true), StringStyle("'")]
        spec.identifierExtra = [ch("'")]
        spec.capitalizedIsType = true
        spec.lineStartFunctions = true
        spec.callIsFunction = false
        return spec
    }()

    static let php: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["abstract", "and", "array", "as", "break", "callable", "case", "catch", "class", "clone", "const", "continue",
                         "declare", "default", "do", "echo", "else", "elseif", "empty", "enddeclare", "endfor", "endforeach", "endif",
                         "endswitch", "endwhile", "enum", "extends", "final", "finally", "fn", "for", "foreach", "function", "global",
                         "goto", "if", "implements", "include", "include_once", "instanceof", "insteadof", "interface", "isset",
                         "list", "match", "namespace", "new", "or", "print", "private", "protected", "public", "readonly", "require",
                         "require_once", "return", "static", "switch", "throw", "trait", "try", "unset", "use", "var", "while", "xor",
                         "yield", "self", "parent"]
        spec.caseInsensitive = true
        spec.types = ["int", "float", "string", "bool", "array", "object", "mixed", "void", "never", "iterable", "callable", "null"]
        spec.constants = ["true", "false", "null"]
        spec.functionDefiners = ["function", "fn"]
        spec.typeDefiners = ["class", "interface", "trait", "enum", "extends", "implements", "new", "namespace", "use", "instanceof"]
        spec.lineComments = [pattern("#"), pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("\"", multiline: true, interpolation: [Interpolation("{$", "}"), .dollarName]),
                        StringStyle("'", escapes: false, multiline: true),
                        StringStyle("`")]
        spec.bracketAttributes = true
        spec.variablePrefixes = [pattern("$")]
        spec.heredocs = .php
        spec.memberAccess = [pattern("->"), pattern("::"), pattern("?->")]
        spec.capitalizedIsType = true
        spec.upperCaseIsConstant = true
        return spec
    }()
}
