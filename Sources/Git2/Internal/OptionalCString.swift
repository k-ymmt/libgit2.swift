import Foundation

/// Invokes `body` with either a `UnsafePointer<CChar>?` that points at the
/// UTF-8 contents of `string`, or `nil` when `string` is `nil`. The pointer
/// is valid only for the duration of the closure.
///
/// Mirrors the shape of `String.withCString` but accepts an optional and
/// threads `nil` through unchanged — libgit2's option structs use `NULL`
/// pointers as "not set", and this helper makes that pattern one line at
/// the call site.
internal func withOptionalCString<R>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) throws(GitError) -> R
) throws(GitError) -> R {
    if let string {
        // String.withCString is rethrows-untyped. Carry the result across
        // the boundary as a Result<R, GitError> the same way the other
        // bridges do.
        let result: Result<R, GitError> = string.withCString { cstr in
            do {
                return .success(try body(cstr))
            } catch let error as GitError {
                return .failure(error)
            } catch {
                fatalError("unreachable: typed throws guarantees GitError")
            }
        }
        return try result.get()
    } else {
        return try body(nil)
    }
}
