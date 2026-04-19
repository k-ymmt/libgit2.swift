import Testing

/// Root suite for every test that touches the libgit2 lifecycle via
/// `Git.bootstrap()` / `Git.shutdown()`. `@Suite(.serialized)` guarantees that
/// all nested suites and their tests run strictly serially, avoiding flakes
/// caused by the global refcount moving underneath any single test.
///
/// Nested suites are declared by extending this type in their own file.
@Suite(.serialized)
struct RuntimeSensitiveTests {}
