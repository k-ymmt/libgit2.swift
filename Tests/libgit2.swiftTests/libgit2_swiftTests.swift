import Testing
@testable import libgit2_swift

@Test
func initAndShutdown() {
    let initResult = git_libgit2_init()
    #expect(initResult >= 0)

    let shutdownResult = git_libgit2_shutdown()
    #expect(shutdownResult >= 0)
}

@Test
func reportsExpectedVersion() {
    // Pinned to libgit2 v1.9.x — update when the submodule is bumped.
    var major: Int32 = 0
    var minor: Int32 = 0
    var rev: Int32 = 0
    _ = git_libgit2_version(&major, &minor, &rev)
    #expect(major == 1)
    #expect(minor == 9)
}
