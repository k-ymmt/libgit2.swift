public struct GitError: Error, Sendable, Equatable, CustomStringConvertible {
    public let code: Code
    public let `class`: Class
    public let message: String

    public init(code: Code, class: Class, message: String) {
        self.code = code
        self.class = `class`
        self.message = message
    }

    public var description: String {
        "GitError(\(code), \(`class`)): \(message)"
    }

    public enum Code: Sendable, Equatable {
        case ok
        case notFound
        case exists
        case ambiguous
        case bufferTooShort
        case user
        case bareRepo
        case unbornBranch
        case unmerged
        case nonFastForward
        case invalidSpec
        case conflict
        case locked
        case modified
        case auth
        case certificate
        case applied
        case peel
        case endOfFile
        case invalid
        case uncommitted
        case directory
        case mergeConflict
        case passthrough
        case iterationOver
        case retry
        case mismatch
        case indexDirty
        case applyFail
        case owner
        case timeout
        case unchanged
        case notSupported
        case readOnly
        case unknown(Int32)
    }

    public enum Class: Sendable, Equatable {
        case none
        case noMemory
        case os
        case invalid
        case reference
        case zlib
        case repository
        case config
        case regex
        case odb
        case index
        case object
        case net
        case tag
        case tree
        case indexer
        case ssl
        case submodule
        case thread
        case stash
        case checkout
        case fetchHead
        case merge
        case ssh
        case filter
        case revert
        case callback
        case cherrypick
        case describe
        case rebase
        case filesystem
        case patch
        case worktree
        case sha
        case http
        case `internal`
        case grafts
        case unknown(Int32)
    }
}
