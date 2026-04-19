/// Namespace for the libgit2 runtime lifecycle.
///
/// libgit2 requires a one-time process-level initialization before any repository
/// can be opened. Call ``bootstrap()`` once at program start; call ``shutdown()``
/// the matching number of times when you are done (or let the process exit).
///
/// ```swift
/// import Git2
///
/// try Git.bootstrap()
/// defer { try? Git.shutdown() }
///
/// let repo = try Repository.open(at: URL(filePath: "/path/to/repo"))
/// ```
///
/// ``bootstrap()`` and ``shutdown()`` are reference-counted and safe to call
/// multiple times. Using any Git2 API that touches libgit2 without a preceding
/// ``bootstrap()`` trips a `preconditionFailure`.
public enum Git {
    /// Initializes libgit2.
    ///
    /// Safe to call multiple times; libgit2 itself reference-counts initialization.
    /// Each call should be balanced by a matching ``shutdown()`` call — the final
    /// pair releases libgit2's internal state.
    ///
    /// - Throws: ``GitError`` if libgit2 reports an initialization failure.
    public static func bootstrap() throws(GitError) {
        try GitRuntime.shared.bootstrap()
    }

    /// Releases one ``bootstrap()`` reference.
    ///
    /// Only the final matching call performs the actual libgit2 shutdown. Calling
    /// ``shutdown()`` more times than ``bootstrap()`` is a no-op and does not
    /// underflow.
    ///
    /// - Throws: ``GitError`` if libgit2 reports a shutdown failure.
    public static func shutdown() throws(GitError) {
        try GitRuntime.shared.shutdown()
    }

    /// Whether libgit2 has been initialized at least once with no matching
    /// ``shutdown()`` yet.
    public static var isBootstrapped: Bool {
        GitRuntime.shared.isBootstrapped
    }

    /// The libgit2 runtime version. Callable even before ``bootstrap()``.
    public static var version: Version {
        Version.current
    }
}
