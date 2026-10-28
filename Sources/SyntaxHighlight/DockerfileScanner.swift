/// Dockerfile: instructions, then the rest of the line as a shell command or as arguments.
struct DockerfileScanner: LineScanner {
    private let shell = CodeScanner(.bash)
    private let arguments = CodeScanner(.dockerfileArguments)

    func scan(_ line: Line, from start: Int, stopAt: Pattern?, state: inout ScanState, painter: inout LinePainter) -> Int {
        switch state {
        case .embedded(_, _, var inner):
            shell.scan(line, state: &inner, painter: &painter)
            state = continuation(line, inner: inner, shell: true)
            return line.count
        case .continuation:
            var inner = ScanState.none
            arguments.scan(line, state: &inner, painter: &painter)
            state = continuation(line, inner: inner, shell: false)
            return line.count
        default:
            state = .none
        }
        let index = line.indentation
        guard index < line.count else { return line.count }
        if line.at(index) == ch("#") {
            painter.paint(index..<line.count, .comment)
            return line.count
        }
        let end = line.identifierEnd(from: index)
        let word = line.string(index..<end).lowercased()
        guard Self.instructions.contains(word) else {
            var inner = ScanState.none
            arguments.scan(line, state: &inner, painter: &painter)
            return line.count
        }
        painter.paint(index..<end, .keyword)
        var inner = ScanState.none
        let isShell = Self.shellInstructions.contains(word)
        _ = (isShell ? shell : arguments).scan(line, from: end, stopAt: nil, state: &inner, painter: &painter)
        state = continuation(line, inner: inner, shell: isShell)
        return line.count
    }

    private func continuation(_ line: Line, inner: ScanState, shell: Bool) -> ScanState {
        let continues = line.trailingBackslash || (inner != .none && !isContinuation(inner))
        guard continues else { return .none }
        return shell ? .embedded(.bash, close: "", inner: inner) : .continuation(command: false)
    }

    private func isContinuation(_ state: ScanState) -> Bool {
        if case .continuation = state { return true }
        return false
    }

    private static let instructions: Set<String> = ["from", "run", "cmd", "label", "maintainer", "expose", "env", "add", "copy",
                                                    "entrypoint", "volume", "user", "workdir", "arg", "onbuild", "stopsignal",
                                                    "healthcheck", "shell"]
    private static let shellInstructions: Set<String> = ["run", "cmd", "entrypoint", "healthcheck", "shell"]
}
