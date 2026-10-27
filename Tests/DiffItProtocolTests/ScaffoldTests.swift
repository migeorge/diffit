import Testing
@testable import DiffItProtocol

@Test func bundleIdentifier() {
    #expect(DiffItPaths.bundleIdentifier == "dev.diffit.app")
}
