import Cgit2

extension Repository {
    /// Builds a new tree from a flat list of entries and writes it to the ODB.
    ///
    /// All entries must be top-level of the new tree. Sub-directories are
    /// represented by entries whose ``TreeBuilderEntry/filemode`` is `.tree`
    /// and whose ``TreeBuilderEntry/oid`` is an existing tree OID.
    ///
    /// - Throws: ``GitError`` — including ``GitError/Code/exists`` if two
    ///   entries share a name, and ``GitError/Code/invalid`` if a filemode does
    ///   not match the kind of the referenced object.
    public func tree(entries: [TreeBuilderEntry]) throws(GitError) -> Tree {
        try lock.withLock { () throws(GitError) -> Tree in
            var builder: OpaquePointer?
            try check(git_treebuilder_new(&builder, handle, nil))
            defer { git_treebuilder_free(builder) }

            var seenNames = Set<String>()
            for entry in entries {
                // Check for duplicate names in the input
                if !seenNames.insert(entry.name).inserted {
                    throw GitError(code: .exists, class: .invalid, message: "duplicate entry name: \(entry.name)")
                }

                var oid = entry.oid.raw
                let result = entry.name.withCString { name in
                    git_treebuilder_insert(nil, builder, name, &oid, entry.filemode.raw)
                }
                try check(result)
            }

            var treeOID = git_oid()
            try check(git_treebuilder_write(&treeOID, builder))

            var treeHandle: OpaquePointer?
            try check(git_tree_lookup(&treeHandle, handle, &treeOID))
            return Tree(handle: treeHandle!, repository: self)
        }
    }
}
