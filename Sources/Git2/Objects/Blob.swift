import Cgit2
import Foundation

/// A Git blob — the raw byte content of a file as stored in the object
/// database.
public final class Blob: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this blob belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_blob_free(handle)
    }

    /// This blob's OID.
    public var oid: OID {
        repository.lock.withLock {
            // libgit2 contract: git_blob_id is non-NULL for a valid handle.
            OID(raw: git_blob_id(handle)!.pointee)
        }
    }

    /// The blob's size in bytes.
    public var size: Int64 {
        repository.lock.withLock {
            Int64(git_blob_rawsize(handle))
        }
    }

    /// A copy of the blob's raw bytes.
    public var content: Data {
        repository.lock.withLock {
            let count = Int(git_blob_rawsize(handle))
            guard count > 0, let raw = git_blob_rawcontent(handle) else {
                return Data()
            }
            return Data(bytes: raw, count: count)
        }
    }

    /// libgit2's heuristic for whether the blob is binary (presence of a NUL
    /// byte in the first N bytes). Not a certainty; same heuristic Git uses
    /// when deciding whether to apply textual diffs.
    public var isBinary: Bool {
        repository.lock.withLock {
            git_blob_is_binary(handle) != 0
        }
    }
}
