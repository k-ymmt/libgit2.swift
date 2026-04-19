import Cgit2

@inline(__always)
internal func check(_ result: Int32) throws(GitError) {
    guard result < 0 else { return }
    throw GitError.fromLibgit2(result)
}
