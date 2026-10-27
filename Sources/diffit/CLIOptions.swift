import Foundation

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case failed(String)

    var description: String {
        switch self {
        case .usage(let s), .failed(let s): return s
        }
    }
}

enum Command {
    case activate
    case compare(old: String, new: String, displayPath: String?)
    case gitConfig
    case stubServer
    case version
    case help
}

struct CLIOptions {
    static let version = "0.1.0"

    var command: Command = .activate
    var oldLabel: String?
    var newLabel: String?
    var title: String?

    static let usage = """
    usage: diffit                                  launch/activate the app
           diffit OLD NEW [DISPLAYPATH]            compare two files or two directories
           diffit --git-config                     configure git to use diffit as its difftool
           diffit --old-label L --new-label L      override side labels
           diffit --title T                        override changeset title
           diffit --version | --help

    OLD or NEW may be /dev/null for an added or deleted file.
    """

    static func parse(_ args: [String]) throws -> CLIOptions {
        var options = CLIOptions()
        var positional: [String] = []
        var i = 0
        func value(for flag: String) throws -> String {
            i += 1
            guard i < args.count else { throw CLIError.usage("\(flag) needs a value") }
            return args[i]
        }
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--git-config": options.command = .gitConfig
            case "--stub-server": options.command = .stubServer
            case "--version", "-v": options.command = .version
            case "--help", "-h": options.command = .help
            case "--old-label": options.oldLabel = try value(for: arg)
            case "--new-label": options.newLabel = try value(for: arg)
            case "--title": options.title = try value(for: arg)
            case "--": positional.append(contentsOf: args[(i + 1)...]); i = args.count
            default:
                if arg.hasPrefix("-") && arg.count > 1 { throw CLIError.usage("unknown option \(arg)") }
                positional.append(arg)
            }
            i += 1
        }

        switch options.command {
        case .activate:
            switch positional.count {
            case 0: break
            case 2, 3: options.command = .compare(old: positional[0], new: positional[1],
                                                  displayPath: positional.count == 3 ? positional[2] : nil)
            default: throw CLIError.usage("expected OLD NEW [DISPLAYPATH]\n\n" + usage)
            }
        default:
            if !positional.isEmpty { throw CLIError.usage("unexpected argument \(positional[0])") }
        }
        return options
    }
}
