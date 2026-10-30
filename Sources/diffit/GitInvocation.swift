import Darwin
import DiffItProtocol
import Foundation

/// Finds the `git diff` (or `git difftool`) command this process descends from and returns its
/// arguments after the subcommand, so the app can run the same comparison again later. In
/// per-file mode `git difftool` runs `git diff <user arguments>` and that is an ancestor; in
/// directory mode only the `difftool` command itself is, so its own options are stripped. A few
/// `sysctl` calls, about 0.2 ms: nothing is executed.
enum GitInvocation {
    static func diffArguments() -> [String]? {
        var pid = getppid()
        var fromDifftool: [String]?
        for _ in 0..<8 {
            guard pid > 1, let argv = arguments(of: pid), let executable = argv.first else { break }
            if (executable as NSString).lastPathComponent == "git", let index = subcommandIndex(in: argv) {
                let rest = Array(argv[(index + 1)...])
                switch argv[index] {
                case "diff": return rest
                case "difftool": fromDifftool = fromDifftool ?? GitDiffArguments.fromDifftool(rest)
                default: break
                }
            }
            guard let parent = parentProcess(of: pid) else { break }
            pid = parent
        }
        return fromDifftool
    }

    // MARK: - Private

    /// Index of git's subcommand: the first argument that is not a global option or its value.
    private static func subcommandIndex(in argv: [String]) -> Int? {
        var index = 1
        while index < argv.count {
            let argument = argv[index]
            if !argument.hasPrefix("-") { return index }
            if globalValueOptions.contains(argument) { index += 1 }
            index += 1
        }
        return nil
    }

    private static let globalValueOptions: Set<String> = [
        "-c", "-C", "--git-dir", "--work-tree", "--namespace", "--config-env", "--attr-source",
    ]

    private static func parentProcess(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    /// `KERN_PROCARGS2`: argc, the executable path, padding, then argv and the environment,
    /// NUL-separated.
    private static func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        let argc = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }   // executable path
        while index < size, buffer[index] == 0 { index += 1 }   // padding
        var result: [String] = []
        var start = index
        while result.count < argc, index < size {
            if buffer[index] == 0 {
                result.append(String(decoding: buffer[start..<index], as: UTF8.self))
                start = index + 1
            }
            index += 1
        }
        return result
    }
}
