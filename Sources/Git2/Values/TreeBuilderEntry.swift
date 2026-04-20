/// One entry to insert when building a new tree via
/// ``Repository/tree(entries:)``.
public struct TreeBuilderEntry: Sendable, Equatable {
    /// The entry's basename (no path separators).
    public let name: String

    /// The OID of the blob, sub-tree, or submodule commit the entry points at.
    public let oid: OID

    /// The Git filemode — distinguishes regular blob, executable blob,
    /// symbolic link, sub-tree, and submodule.
    public let filemode: TreeEntry.FileMode

    public init(name: String, oid: OID, filemode: TreeEntry.FileMode) {
        self.name = name
        self.oid = oid
        self.filemode = filemode
    }
}
