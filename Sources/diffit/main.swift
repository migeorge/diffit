import Foundation
import DiffItProtocol

// The CLI git invokes once per changed path. Budget with the app running: < 30 ms.

func fail(_ message: String, status: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("diffit: \(message)\n".utf8))
    exit(status)
}

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
        for line in try Git.configure() { print(line) }
        print("\nOptional alias (not set):\n  git config --global alias.dt difftool")

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
