import Cgit2

extension Repository {
    /// Creates a lightweight tag — `refs/tags/<name>` that points directly at
    /// `target`. No tag object is written.
    ///
    /// - Parameters:
    ///   - name: The short tag name (e.g. `"v1.0"`). No `refs/tags/` prefix.
    ///   - target: The commit the tag should point at.
    ///   - force: If `true`, overwrite an existing tag of the same name.
    /// - Returns: The created reference.
    public func createLightweightTag(
        named name: String,
        target: Commit,
        force: Bool = false
    ) throws(GitError) -> Reference {
        try lock.withLock { () throws(GitError) -> Reference in
            var oid = git_oid()
            let result: Int32 = name.withCString { namePtr in
                git_tag_create_lightweight(&oid, handle, namePtr, target.handle, force ? 1 : 0)
            }
            try check(result)

            // Name already passed git_tag_create_lightweight validation above,
            // so the derived "refs/tags/<name>" is guaranteed to be a valid
            // refspec and the lookup will succeed.
            var ref: OpaquePointer?
            let resultLookup: Int32 = "refs/tags/\(name)".withCString { full in
                git_reference_lookup(&ref, handle, full)
            }
            try check(resultLookup)
            return Reference(handle: ref!, repository: self)
        }
    }

    /// Creates an annotated tag — writes a `tag` object carrying `tagger` and
    /// `message`, and installs `refs/tags/<name>` pointing at that object.
    ///
    /// - Returns: The created ``Tag`` handle (annotated).
    public func createAnnotatedTag(
        named name: String,
        target: Commit,
        tagger: Signature,
        message: String,
        force: Bool = false
    ) throws(GitError) -> Tag {
        try lock.withLock { () throws(GitError) -> Tag in
            let taggerHandle = try signatureHandle(for: tagger)
            defer { git_signature_free(taggerHandle) }

            var tagOID = git_oid()
            let result: Int32 = name.withCString { namePtr in
                message.withCString { msgPtr in
                    // Commit.handle is a git_commit *, which is a subtype of
                    // git_object * in libgit2's C type hierarchy. OpaquePointer
                    // is already type-erased on the Swift side.
                    git_tag_create(
                        &tagOID, handle, namePtr,
                        target.handle,
                        taggerHandle, msgPtr,
                        force ? 1 : 0
                    )
                }
            }
            try check(result)

            var tagHandle: OpaquePointer?
            try check(git_tag_lookup(&tagHandle, handle, &tagOID))
            return Tag(handle: tagHandle!, repository: self)
        }
    }

    /// Deletes the tag `refs/tags/<name>`.
    ///
    /// For annotated tags, `refs/tags/<name>` is removed; the tag object itself
    /// becomes unreferenced in the ODB but is not removed (standard Git
    /// behavior — GC will prune it).
    ///
    /// - Throws: ``GitError`` — ``GitError/Code/notFound`` if the tag does not
    ///   exist; other ``GitError`` codes for repository or filesystem issues
    ///   surfaced by libgit2.
    public func deleteTag(named name: String) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            let result: Int32 = name.withCString { namePtr in
                git_tag_delete(handle, namePtr)
            }
            try check(result)
        }
    }
}
