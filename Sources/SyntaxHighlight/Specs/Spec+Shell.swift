extension LanguageSpec {
    static let bash: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done", "in", "function",
                         "select", "time", "coproc", "break", "continue", "return", "exit"]
        spec.builtins = ["echo", "cd", "pwd", "export", "local", "declare", "typeset", "readonly", "unset", "shift", "source", "set",
                         "read", "printf", "eval", "exec", "test", "trap", "alias", "unalias", "pushd", "popd", "dirs", "let",
                         "getopts", "wait", "kill", "jobs", "fg", "bg", "type", "hash", "command", "builtin", "enable", "ulimit",
                         "umask", "true", "false", "mapfile", "readarray", "caller", "complete", "compgen", "disown", "help",
                         "history", "logout", "suspend", "times"]
        spec.commandTriggers = ["if", "then", "else", "elif", "do", "while", "until", "time", "coproc"]
        spec.commandWrappers = ["sudo", "doas", "exec", "command", "builtin", "nohup", "env", "nice", "xargs", "time", "watch"]
        spec.functionDefiners = ["function"]
        spec.lineComments = [pattern("#")]
        spec.commentNeedsBoundary = true
        spec.strings = [StringStyle("$'", "'"),
                        StringStyle("\"", multiline: true, interpolation: [.dollarBrace, Interpolation("$(", ")"), .dollarName,
                                                                            Interpolation("`", "`")]),
                        StringStyle("'", escapes: false, multiline: true)]
        spec.variablePrefixes = [pattern("$")]
        spec.variableSpecials = [ch("#"), ch("?"), ch("@"), ch("*"), ch("!"), ch("$"), ch("-"), ch("_")]
        spec.heredocs = .shell
        spec.commandPosition = true
        spec.assignmentIsProperty = true
        return spec
    }()

    static let fish: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["function", "end", "if", "else", "switch", "case", "for", "in", "while", "begin", "and", "or", "not",
                         "return", "break", "continue"]
        spec.builtins = ["set", "echo", "string", "math", "test", "command", "builtin", "source", "abbr", "alias", "bind", "cd", "pwd",
                         "count", "contains", "printf", "read", "exit", "type", "functions", "status", "argparse", "exec", "eval",
                         "emit", "jobs", "fg", "bg", "wait", "disown", "set_color", "random", "realpath", "seq", "ulimit", "umask",
                         "commandline", "complete", "history", "isatty", "time", "trap", "true", "false", "block", "breakpoint",
                         "dirs", "pushd", "popd", "nextd", "prevd", "path", "psub", "vared", "fish_add_path", "fish_config",
                         "funced", "funcsave", "fish_opt", "getopts", "ulimit", "exit", "printf", "jobs", "fish_indent"]
        spec.commandTriggers = ["if", "else", "while", "and", "or", "not", "begin"]
        spec.commandWrappers = ["command", "builtin", "exec", "sudo", "doas", "time", "env", "xargs", "nohup"]
        spec.functionDefiners = ["function"]
        spec.lineComments = [pattern("#")]
        spec.commentNeedsBoundary = true
        spec.strings = [StringStyle("\"", multiline: true, interpolation: [Interpolation("$(", ")"), .dollarName]),
                        StringStyle("'", escapes: false, multiline: true)]
        spec.variablePrefixes = [pattern("$")]
        spec.variableSpecials = [ch("$")]
        spec.commandPosition = true
        return spec
    }()

    /// Everything after a Dockerfile instruction that is not a shell command.
    static let dockerfileArguments: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["as"]
        spec.caseInsensitive = true
        spec.lineComments = [pattern("#")]
        spec.commentNeedsBoundary = true
        spec.strings = [StringStyle("\"", interpolation: [.dollarBrace, .dollarName]), StringStyle("'", escapes: false)]
        spec.variablePrefixes = [pattern("$")]
        return spec
    }()
}
