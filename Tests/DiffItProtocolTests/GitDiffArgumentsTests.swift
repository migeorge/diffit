import Testing
@testable import DiffItProtocol

@Suite struct GitDiffArgumentsTests {
    @Test func stripsDifftoolOptions() {
        let args = ["-y", "-t", "diffit", "--dir-diff", "HEAD~2", "--", "src"]
        #expect(GitDiffArguments.fromDifftool(args) == ["HEAD~2", "--", "src"])
    }

    @Test func attachedAndEqualsForms() {
        #expect(GitDiffArguments.fromDifftool(["--tool=diffit", "-tdiffit", "-x", "cmd", "--extcmd=cmd", "--cached"]) == ["--cached"])
    }

    @Test func keepsDiffOptionsAndPathsAfterDoubleDash() {
        let args = ["-M", "--no-prompt", "main...feature", "--", "-y", "--tool"]
        #expect(GitDiffArguments.fromDifftool(args) == ["-M", "main...feature", "--", "-y", "--tool"])
    }

    @Test func emptyForPlainDifftool() {
        #expect(GitDiffArguments.fromDifftool(["-y", "-d"]) == [])
    }
}
