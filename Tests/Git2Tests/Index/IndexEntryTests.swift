import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexEntryTests {
        @Test
        func stageInit_coversAllFourValues() {
            let mask = UInt16(GIT_INDEX_ENTRY_STAGEMASK)
            let shift = UInt16(GIT_INDEX_ENTRY_STAGESHIFT)
            let normal   = IndexEntry.Stage(flags: 0)
            let ancestor = IndexEntry.Stage(flags: (UInt16(1) << shift) & mask)
            let ours     = IndexEntry.Stage(flags: (UInt16(2) << shift) & mask)
            let theirs   = IndexEntry.Stage(flags: (UInt16(3) << shift) & mask)
            #expect(normal   == .normal)
            #expect(ancestor == .ancestor)
            #expect(ours     == .ours)
            #expect(theirs   == .theirs)
        }

        @Test
        func entry_initIsStoredVerbatim() {
            let oid = OID(raw: git_oid())
            let e = IndexEntry(
                path: "README.md",
                oid: oid,
                filemode: .blob,
                stage: .normal
            )
            #expect(e.path == "README.md")
            #expect(e.oid == oid)
            #expect(e.filemode == .blob)
            #expect(e.stage == .normal)
        }

        @Test
        func entry_isEquatable() {
            let oid = OID(raw: git_oid())
            let a = IndexEntry(path: "a", oid: oid, filemode: .blob, stage: .normal)
            let b = IndexEntry(path: "a", oid: oid, filemode: .blob, stage: .normal)
            let c = IndexEntry(path: "a", oid: oid, filemode: .blob, stage: .ours)
            #expect(a == b)
            #expect(a != c)
        }

        @Test
        func conflict_initIsStoredVerbatim() {
            let oid = OID(raw: git_oid())
            let ours = IndexEntry(path: "a", oid: oid, filemode: .blob, stage: .ours)
            let theirs = IndexEntry(path: "a", oid: oid, filemode: .blob, stage: .theirs)
            let c = IndexConflict(
                path: "a",
                ancestor: nil,
                ours: ours,
                theirs: theirs
            )
            #expect(c.path == "a")
            #expect(c.ancestor == nil)
            #expect(c.ours == ours)
            #expect(c.theirs == theirs)
        }

        @Test
        func conflict_isEquatable() {
            let oid = OID(raw: git_oid())
            let ours = IndexEntry(path: "a", oid: oid, filemode: .blob, stage: .ours)
            let a = IndexConflict(path: "a", ancestor: nil, ours: ours, theirs: nil)
            let b = IndexConflict(path: "a", ancestor: nil, ours: ours, theirs: nil)
            let c = IndexConflict(path: "b", ancestor: nil, ours: ours, theirs: nil)
            #expect(a == b)
            #expect(a != c)
        }
    }
}
