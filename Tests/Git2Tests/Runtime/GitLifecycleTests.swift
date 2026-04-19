import Testing
@testable import Git2

// These tests observe `Git.isBootstrapped` (a process-global refcount) and so
// must run serially with any other test that calls `Git.bootstrap()` /
// `Git.shutdown()`. Swift Testing only guarantees serialization *within* a
// `@Suite(.serialized)` — separate suites still run in parallel. To get true
// mutual exclusion between every test that touches the runtime, all such tests
// live under one serialized root suite, `RuntimeSensitiveTests`, declared in
// `RuntimeSensitiveTests.swift`. The lifecycle tests are a nested suite.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct GitLifecycleTests {
        @Test
        func bootstrapAndShutdownAreIdempotent() throws {
            // Ensure fully shut down first (other tests may have bootstrapped).
            while Git.isBootstrapped { try Git.shutdown() }

            try Git.bootstrap()
            try Git.bootstrap()
            #expect(Git.isBootstrapped)
            try Git.shutdown()
            #expect(Git.isBootstrapped)        // still bootstrapped after one shutdown
            try Git.shutdown()
            #expect(Git.isBootstrapped == false)
        }

        @Test
        func shutdownWithoutBootstrapIsNoOp() throws {
            // Ensure fully shut down first.
            while Git.isBootstrapped { try Git.shutdown() }
            try Git.shutdown()      // should not throw
            #expect(Git.isBootstrapped == false)
        }

        @Test
        func versionIsAvailableWithoutBootstrap() throws {
            while Git.isBootstrapped { try Git.shutdown() }
            let v = Git.version
            #expect(v.major == 1)
            #expect(v.minor == 9)
        }
    }
}
