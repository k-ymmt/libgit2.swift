/// A Git refspec expressed as a raw string.
///
/// Refspecs take the form `[+]<src>:<dst>` where the optional `+`
/// enables non-fast-forward updates. Examples:
///
/// - `"refs/heads/main"` — fetch-only shorthand for `main`.
/// - `"+refs/heads/*:refs/remotes/origin/*"` — mirror all local heads
///   into the `origin` remote-tracking namespace.
///
/// v0.5b-i takes refspecs as opaque strings. libgit2 validates them at
/// fetch / config-mutation time; a syntactically invalid refspec surfaces
/// as ``GitError/Code/invalidSpec``. A parsed/split API (`src`, `dst`,
/// `direction`, match testing) can land additively in a later slice.
public struct Refspec: Sendable, Hashable {
    /// The raw refspec string.
    public let string: String

    /// Wraps a raw refspec string without parsing.
    public init(_ string: String) {
        self.string = string
    }
}
