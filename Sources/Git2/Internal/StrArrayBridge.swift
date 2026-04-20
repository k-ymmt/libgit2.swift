import Cgit2
import Foundation   // re-exports Darwin's strdup / free on Apple platforms

/// Invokes `body` with a `git_strarray *` view of `paths` — or `nil` if
/// `paths` is empty (libgit2 treats a `NULL` strarray as "all paths").
///
/// The strarray and its backing C strings are valid only for the duration
/// of the closure. Callers must not retain the pointer.
internal func withGitStrArray<R>(
    _ paths: [String],
    _ body: (UnsafePointer<git_strarray>?) throws(GitError) -> R
) throws(GitError) -> R {
    if paths.isEmpty {
        return try body(nil)
    }

    let count = paths.count
    let buffer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: count)

    // Initialize every slot to nil up-front so the cleanup path is safe
    // whether or not every strdup below completes.
    buffer.initialize(repeating: nil, count: count)
    defer {
        for i in 0..<count {
            if let p = buffer[i] { free(p) }
        }
        buffer.deinitialize(count: count)
        buffer.deallocate()
    }

    for i in 0..<count {
        guard let duped = paths[i].withCString({ strdup($0) }) else {
            throw GitError(code: .unknown(-1), class: .noMemory, message: "strdup failed")
        }
        buffer[i] = duped
    }

    var arr = git_strarray(strings: buffer, count: count)
    // `withUnsafePointer` uses untyped `rethrows`, which can't forward typed
    // throws. Carry the outcome across the boundary as a `Result<R, GitError>`.
    let result: Result<R, GitError> = withUnsafePointer(to: &arr) { ptr in
        do {
            return .success(try body(ptr))
        } catch let error as GitError {
            return .failure(error)
        } catch {
            fatalError("unreachable: typed throws guarantees GitError")
        }
    }
    return try result.get()
}
