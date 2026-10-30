import Foundation

/// Helpers for the `git diff` arguments a message carries (`OpenMessage.gitDiffArguments`).
public enum GitDiffArguments {
    /// The `git diff` arguments inside a `git difftool` command line: difftool's own options are
    /// removed (with their values), everything else is kept in order. Used when the CLI's only git
    /// ancestor is the `difftool` invocation itself (directory mode).
    public static func fromDifftool(_ arguments: [String]) -> [String] {
        var result: [String] = []
        var afterDoubleDash = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            index += 1
            if afterDoubleDash {
                result.append(argument)
                continue
            }
            if argument == "--" {
                afterDoubleDash = true
                result.append(argument)
                continue
            }
            if difftoolFlags.contains(argument) { continue }
            if difftoolValueOptions.contains(argument) {
                index += 1   // the value
                continue
            }
            if difftoolValueOptions.contains(where: { $0.hasPrefix("--") && argument.hasPrefix($0 + "=") }) { continue }
            // Short options with the value attached: -tdiffit, -xcmd.
            if (argument.hasPrefix("-t") || argument.hasPrefix("-x")), !argument.hasPrefix("--"), argument.count > 2 { continue }
            result.append(argument)
        }
        return result
    }

    private static let difftoolFlags: Set<String> = [
        "-y", "--no-prompt", "--prompt", "-g", "--gui", "--no-gui", "-d", "--dir-diff",
        "--symlinks", "--no-symlinks", "--tool-help", "--trust-exit-code", "--no-trust-exit-code",
    ]
    private static let difftoolValueOptions: Set<String> = ["-t", "--tool", "-x", "--extcmd"]
}
