import Cgit2

extension GitError.Code {
    internal static func from(_ raw: Int32) -> GitError.Code {
        switch raw {
        case GIT_OK.rawValue:             return .ok
        case GIT_ERROR.rawValue:          return .unknown(raw)
        case GIT_ENOTFOUND.rawValue:      return .notFound
        case GIT_EEXISTS.rawValue:        return .exists
        case GIT_EAMBIGUOUS.rawValue:     return .ambiguous
        case GIT_EBUFS.rawValue:          return .bufferTooShort
        case GIT_EUSER.rawValue:          return .user
        case GIT_EBAREREPO.rawValue:      return .barelyRepo
        case GIT_EUNBORNBRANCH.rawValue:  return .unbornBranch
        case GIT_EUNMERGED.rawValue:      return .unmerged
        case GIT_ENONFASTFORWARD.rawValue: return .nonFastForward
        case GIT_EINVALIDSPEC.rawValue:   return .invalidSpec
        case GIT_ECONFLICT.rawValue:      return .conflict
        case GIT_ELOCKED.rawValue:        return .locked
        case GIT_EMODIFIED.rawValue:      return .modified
        case GIT_EAUTH.rawValue:          return .auth
        case GIT_ECERTIFICATE.rawValue:   return .certificate
        case GIT_EAPPLIED.rawValue:       return .applied
        case GIT_EPEEL.rawValue:          return .peel
        case GIT_EEOF.rawValue:           return .endOfFile
        case GIT_EINVALID.rawValue:       return .invalid
        case GIT_EUNCOMMITTED.rawValue:   return .uncommitted
        case GIT_EDIRECTORY.rawValue:     return .directory
        case GIT_EMERGECONFLICT.rawValue: return .mergeConflict
        case GIT_PASSTHROUGH.rawValue:    return .passthrough
        case GIT_ITEROVER.rawValue:       return .iterationOver
        case GIT_RETRY.rawValue:          return .retry
        case GIT_EMISMATCH.rawValue:      return .mismatch
        case GIT_EINDEXDIRTY.rawValue:    return .indexDirty
        case GIT_EAPPLYFAIL.rawValue:     return .applyFail
        case GIT_EOWNER.rawValue:         return .owner
        case GIT_TIMEOUT.rawValue:        return .timeout
        case GIT_EUNCHANGED.rawValue:     return .unchanged
        case GIT_ENOTSUPPORTED.rawValue:  return .notSupported
        case GIT_EREADONLY.rawValue:      return .readOnly
        default:                          return .unknown(raw)
        }
    }
}

extension GitError.Class {
    internal static func from(_ raw: Int32) -> GitError.Class {
        switch raw {
        case Int32(GIT_ERROR_NONE.rawValue):       return .none
        case Int32(GIT_ERROR_NOMEMORY.rawValue):   return .noMemory
        case Int32(GIT_ERROR_OS.rawValue):         return .os
        case Int32(GIT_ERROR_INVALID.rawValue):    return .invalid
        case Int32(GIT_ERROR_REFERENCE.rawValue):  return .reference
        case Int32(GIT_ERROR_ZLIB.rawValue):       return .zlib
        case Int32(GIT_ERROR_REPOSITORY.rawValue): return .repository
        case Int32(GIT_ERROR_CONFIG.rawValue):     return .config
        case Int32(GIT_ERROR_REGEX.rawValue):      return .regex
        case Int32(GIT_ERROR_ODB.rawValue):        return .odb
        case Int32(GIT_ERROR_INDEX.rawValue):      return .index
        case Int32(GIT_ERROR_OBJECT.rawValue):     return .object
        case Int32(GIT_ERROR_NET.rawValue):        return .net
        case Int32(GIT_ERROR_TAG.rawValue):        return .tag
        case Int32(GIT_ERROR_TREE.rawValue):       return .tree
        case Int32(GIT_ERROR_INDEXER.rawValue):    return .indexer
        case Int32(GIT_ERROR_SSL.rawValue):        return .ssl
        case Int32(GIT_ERROR_SUBMODULE.rawValue):  return .submodule
        case Int32(GIT_ERROR_THREAD.rawValue):     return .thread
        case Int32(GIT_ERROR_STASH.rawValue):      return .stash
        case Int32(GIT_ERROR_CHECKOUT.rawValue):   return .checkout
        case Int32(GIT_ERROR_FETCHHEAD.rawValue):  return .fetchHead
        case Int32(GIT_ERROR_MERGE.rawValue):      return .merge
        case Int32(GIT_ERROR_SSH.rawValue):        return .ssh
        case Int32(GIT_ERROR_FILTER.rawValue):     return .filter
        case Int32(GIT_ERROR_REVERT.rawValue):     return .revert
        case Int32(GIT_ERROR_CALLBACK.rawValue):   return .callback
        case Int32(GIT_ERROR_CHERRYPICK.rawValue): return .cherrypick
        case Int32(GIT_ERROR_DESCRIBE.rawValue):   return .describe
        case Int32(GIT_ERROR_REBASE.rawValue):     return .rebase
        case Int32(GIT_ERROR_FILESYSTEM.rawValue): return .filesystem
        case Int32(GIT_ERROR_PATCH.rawValue):      return .patch
        case Int32(GIT_ERROR_WORKTREE.rawValue):   return .worktree
        case Int32(GIT_ERROR_SHA.rawValue):        return .sha
        case Int32(GIT_ERROR_HTTP.rawValue):       return .http
        case Int32(GIT_ERROR_INTERNAL.rawValue):   return .internal
        case Int32(GIT_ERROR_GRAFTS.rawValue):     return .grafts
        default:                                    return .unknown(raw)
        }
    }
}

extension GitError {
    internal static func fromLibgit2(_ result: Int32) -> GitError {
        let raw = git_error_last()
        let message: String
        let klass: Class
        if let raw {
            klass = Class.from(raw.pointee.klass)
            // libgit2 1.x guarantees git_error_last() never returns NULL. When no
            // real error is set it returns a static placeholder with klass
            // GIT_ERROR_NONE and message "no error" — treat that as empty.
            if klass == .none {
                message = ""
            } else {
                message = String(cString: raw.pointee.message)
            }
        } else {
            message = ""
            klass = .none
        }
        return GitError(code: Code.from(result), class: klass, message: message)
    }
}
