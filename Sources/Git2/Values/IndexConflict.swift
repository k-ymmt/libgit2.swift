/// The three-way side collection for one conflicted path in the index.
///
/// libgit2 guarantees that at least one of `ancestor` / `ours` / `theirs` is
/// non-nil for any conflict it returns. The public initializer does not
/// enforce that invariant so tests can build degenerate values freely.
public struct IndexConflict: Sendable, Equatable {
    /// The conflicting path (shared by all non-nil sides).
    public let path: String

    /// The common-ancestor entry (stage 1), or `nil` (e.g. add/add conflicts).
    public let ancestor: IndexEntry?

    /// The "ours" entry (stage 2), or `nil` (e.g. modify/delete conflicts
    /// where we deleted).
    public let ours: IndexEntry?

    /// The "theirs" entry (stage 3), or `nil` (e.g. modify/delete conflicts
    /// where they deleted).
    public let theirs: IndexEntry?

    public init(
        path: String,
        ancestor: IndexEntry?,
        ours: IndexEntry?,
        theirs: IndexEntry?
    ) {
        self.path = path
        self.ancestor = ancestor
        self.ours = ours
        self.theirs = theirs
    }
}
