import Cgit2
import Foundation

extension Repository {
    /// Writes `data` to the object database as a blob and returns its OID.
    ///
    /// The blob becomes part of the ODB immediately. Nothing else references
    /// it until a tree containing this OID is written.
    public func createBlob(data: Data) throws(GitError) -> OID {
        try lock.withLock { () throws(GitError) -> OID in
            var oid = git_oid()
            let result: Int32 = data.withUnsafeBytes { buf -> Int32 in
                // libgit2 accepts NULL when len == 0, but buf.baseAddress is
                // also nil in that case. Pass a non-nil dummy pointer so the
                // C side sees a valid pointer regardless of length.
                let ptr = buf.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!
                return git_blob_create_from_buffer(&oid, handle, ptr, buf.count)
            }
            try check(result)
            return OID(raw: oid)
        }
    }
}
