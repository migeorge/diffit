import Foundation
import DiffItProtocol

// The CLI git invokes once per changed path. Budget with the app running: < 30 ms.

func fail(_ message: String, status: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("diffit: \(message)\n".utf8))
    exit(status)
}

/// This executable's real location (symlinks resolved), the path written into git's config.
let ownPath = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
    .resolvingSymlinksInPath().path

let options: CLIOptions
do {
    options = try CLIOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail("\(error)", status: 2)
}

do {
    switch options.command {
    case .help:
        print(CLIOptions.usage)

    case .version:
        print("diffit \(CLIOptions.version)")

    case .gitConfig:
        for line in try Git.configure(cliPath: ownPath) { print(line) }
        print("\nOptional alias (not set):\n  git config --global alias.dt difftool")

    case .gitUnconfig:
        let removed = try Git.unconfigure()
        print(removed.isEmpty ? "nothing to remove" : "unset " + removed.joined(separator: ", "))

    case .gitCheck:
        let status = try Git.status()
        let configured = status.isConfigured(for: ownPath)
        print("diff.tool = \(status.tool ?? "(unset)")")
        print("difftool.diffit.cmd = \(status.command ?? "(unset)")")
        print("difftool.prompt = \(status.prompt ?? "(unset)")")
        print(configured ? "configured for \(ownPath)" : "not configured for \(ownPath)")
        exit(configured ? 0 : 1)

    case .stubServer:
        try StubServer.run()

    case .activate:
        try AppLauncher.activate()

    case .compare(let old, let new, let displayPath):
        let snapshotter = Snapshotter()
        do {
            let builder = MessageBuilder(options: options, environment: ProcessInfo.processInfo.environment,
                                         snapshotter: snapshotter)
            let message = try builder.build(old: old, new: new, displayPath: displayPath)
            try AppLauncher.send(message)
        } catch {
            snapshotter.discard()
            throw error
        }
    }
} catch {
    fail("\(error)")
}
