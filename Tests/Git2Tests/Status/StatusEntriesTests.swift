import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct StatusEntriesTests {
        @Test
        func statusList_onCleanRepo_returnsZeroCount() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                let list = try repo.statusList()
                #expect(list.count == 0)
            }
        }

        @Test
        func statusList_onBareRepo_throwsBareRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                #expect {
                    _ = try repo.statusList()
                } throws: { error in
                    guard let gitError = error as? GitError else { return false }
                    return gitError.code == .bareRepo
                }
            }
        }

        @Test
        func statusEntries_onCleanRepo_returnsEmpty() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                let entries = try repo.statusEntries()
                #expect(entries.isEmpty)
            }
        }

        @Test
        func statusEntries_untrackedFile_appearsAsWtNew() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("new.txt", contents: "hi", in: dir)

                let entries = try repo.statusEntries()
                #expect(entries.count == 1)
                let entry = try #require(entries.first)
                #expect(entry.path == "new.txt")
                #expect(entry.flags.contains(.wtNew))
                #expect(entry.flags.hasWorkdirChanges)
                #expect(!entry.flags.hasIndexChanges)
            }
        }

        @Test
        func statusEntries_stagedNewFile_appearsAsIndexNew() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("staged.txt", contents: "hi", in: dir)
                let index = try repo.index()
                try index.addPath("staged.txt")
                try index.save()

                let entries = try repo.statusEntries()
                #expect(entries.contains { $0.path == "staged.txt" && $0.flags.contains(.indexNew) })
            }
        }

        @Test
        func statusEntries_modifiedTrackedFile_appearsAsWtModified() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "tracked.txt", contents: "v1", in: dir
                )
                try TestFixture.writeWorkdirFile("tracked.txt", contents: "v2", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "tracked.txt" })
                #expect(entry.flags.contains(.wtModified))
            }
        }

        @Test
        func statusEntries_deletedFromWorkdir_appearsAsWtDeleted() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "keep.txt", contents: "x", in: dir
                )
                try TestFixture.deleteWorkdirFile("keep.txt", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "keep.txt" })
                #expect(entry.flags.contains(.wtDeleted))
            }
        }

        @Test
        func statusEntries_stagedAndThenModified_hasBothFlags() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "rw.txt", contents: "v1", in: dir
                )
                try TestFixture.writeWorkdirFile("rw.txt", contents: "v2", in: dir)
                let index = try repo.index()
                try index.addPath("rw.txt")
                try index.save()
                try TestFixture.writeWorkdirFile("rw.txt", contents: "v3", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "rw.txt" })
                #expect(entry.flags.contains(.indexModified))
                #expect(entry.flags.contains(.wtModified))
            }
        }

        @Test
        func statusEntries_unbornHead_listsWorkdirAgainstEmptyTree() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                try TestFixture.writeWorkdirFile("a.txt", contents: "a", in: dir)

                let entries = try repo.statusEntries()
                #expect(entries.contains { $0.path == "a.txt" && $0.flags.contains(.wtNew) })
            }
        }

        @Test
        func statusEntries_onBareRepo_throwsBareRepo() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try initBareRepo(at: dir)
                #expect {
                    _ = try repo.statusEntries()
                } throws: { error in
                    guard let gitError = error as? GitError else { return false }
                    return gitError.code == .bareRepo
                }
            }
        }

        @Test
        func statusEntries_exposesDiffDelta_forHeadToIndex_andIndexToWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "x.txt", contents: "v1", in: dir
                )
                // Stage v2 (headToIndex) then overwrite workdir with v3 (indexToWorkdir).
                try TestFixture.writeWorkdirFile("x.txt", contents: "v2", in: dir)
                let index = try repo.index()
                try index.addPath("x.txt")
                try index.save()
                try TestFixture.writeWorkdirFile("x.txt", contents: "v3", in: dir)

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "x.txt" })
                #expect(entry.headToIndex != nil)
                #expect(entry.headToIndex?.status == .modified)
                #expect(entry.indexToWorkdir != nil)
                #expect(entry.indexToWorkdir?.status == .modified)
            }
        }

        @Test
        func statusEntries_stagedDelete_appearsAsIndexDeleted() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "doomed.txt", contents: "bye", in: dir
                )
                let index = try repo.index()
                try index.removePath("doomed.txt")
                try index.save()

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "doomed.txt" })
                #expect(entry.flags.contains(.indexDeleted))
            }
        }

        @Test
        func statusEntries_ignoredFile_withIncludeIgnored_appearsAsIgnored() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("*.log\n", in: dir)
                try TestFixture.writeWorkdirFile("app.log", contents: "noise", in: dir)

                let opts = Repository.StatusOptions(flags: [.includeIgnored, .includeUntracked, .recurseUntrackedDirs])
                let entries = try repo.statusEntries(options: opts)
                #expect(entries.contains { $0.path == "app.log" && $0.flags.contains(.ignored) })
            }
        }

        @Test
        func statusEntries_ignoredFile_withoutIncludeIgnored_isAbsent() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("*.log\n", in: dir)
                try TestFixture.writeWorkdirFile("app.log", contents: "noise", in: dir)

                let opts = Repository.StatusOptions(flags: [.includeUntracked, .recurseUntrackedDirs])
                let entries = try repo.statusEntries(options: opts)
                #expect(!entries.contains { $0.path == "app.log" })
            }
        }

        @Test
        func statusEntries_typeChange_fileToSymlink_appearsAsWtTypeChange() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "shape", contents: "f", in: dir
                )
                // Replace the tracked regular file with a symlink.
                try TestFixture.deleteWorkdirFile("shape", in: dir)
                try TestFixture.writeWorkdirSymlink(
                    at: "shape", target: "/tmp/somewhere", in: dir
                )

                let entries = try repo.statusEntries()
                let entry = try #require(entries.first { $0.path == "shape" })
                #expect(entry.flags.contains(.wtTypeChange))
            }
        }

        @Test
        func statusEntries_show_indexOnly_omitsWorkdirChanges() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "t.txt", contents: "v1", in: dir
                )
                // Workdir-only change.
                try TestFixture.writeWorkdirFile("t.txt", contents: "v2", in: dir)

                let opts = Repository.StatusOptions(show: .indexOnly)
                let entries = try repo.statusEntries(options: opts)
                #expect(entries.isEmpty)
            }
        }

        @Test
        func statusEntries_show_workdirOnly_omitsIndexChanges() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "t.txt", contents: "v1", in: dir
                )
                // Stage a modification so there is an INDEX_MODIFIED.
                try TestFixture.writeWorkdirFile("t.txt", contents: "v2", in: dir)
                let index = try repo.index()
                try index.addPath("t.txt")
                try index.save()

                let opts = Repository.StatusOptions(show: .workdirOnly)
                let entries = try repo.statusEntries(options: opts)
                // The staged v2 in index now matches workdir, so nothing shows.
                #expect(entries.isEmpty)
            }
        }

        @Test
        func statusEntries_pathspec_filtersByGlob() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("a.swift", contents: "1", in: dir)
                try TestFixture.writeWorkdirFile("b.txt",   contents: "2", in: dir)

                let opts = Repository.StatusOptions(
                    flags: .defaults, pathspec: ["*.swift"]
                )
                let entries = try repo.statusEntries(options: opts)
                #expect(entries.count == 1)
                #expect(entries[0].path == "a.swift")
            }
        }

        @Test
        func statusEntries_pathspec_disablePathspecMatch_treatsAsLiteral() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("one.txt", contents: "1", in: dir)
                try TestFixture.writeWorkdirFile("two.txt", contents: "2", in: dir)

                // With disablePathspecMatch, "*.txt" is a literal filename, not
                // a glob — so no entries match it.
                let literalOpts = Repository.StatusOptions(
                    flags: [.includeUntracked, .disablePathspecMatch],
                    pathspec: ["*.txt"]
                )
                let literalEntries = try repo.statusEntries(options: literalOpts)
                #expect(literalEntries.isEmpty)

                // Exact-match literal DOES match.
                let exactOpts = Repository.StatusOptions(
                    flags: [.includeUntracked, .disablePathspecMatch],
                    pathspec: ["one.txt"]
                )
                let exactEntries = try repo.statusEntries(options: exactOpts)
                #expect(exactEntries.count == 1)
                #expect(exactEntries[0].path == "one.txt")
            }
        }

        @Test
        func statusEntries_recurseUntrackedDirs_onOff() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeWorkdirFile("sub/one.txt", contents: "1", in: dir)
                try TestFixture.writeWorkdirFile("sub/two.txt", contents: "2", in: dir)

                // OFF: directory is collapsed to a single entry with trailing slash.
                let off = Repository.StatusOptions(flags: [.includeUntracked])
                let offEntries = try repo.statusEntries(options: off)
                #expect(offEntries.contains { $0.path == "sub/" })

                // ON: each file is reported individually.
                let on = Repository.StatusOptions(flags: [.includeUntracked, .recurseUntrackedDirs])
                let onEntries = try repo.statusEntries(options: on)
                let paths = Set(onEntries.map(\.path))
                #expect(paths.contains("sub/one.txt"))
                #expect(paths.contains("sub/two.txt"))
            }
        }

        @Test
        func statusEntries_recurseIgnoredDirs_onOff() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(in: dir)
                try TestFixture.writeGitignore("cache/\n", in: dir)
                try TestFixture.writeWorkdirFile("cache/one.bin", contents: "x", in: dir)
                try TestFixture.writeWorkdirFile("cache/two.bin", contents: "y", in: dir)

                // OFF: entire ignored directory collapsed to one entry with "/" suffix.
                let off = Repository.StatusOptions(flags: [.includeIgnored, .recurseUntrackedDirs])
                let offEntries = try repo.statusEntries(options: off)
                #expect(offEntries.contains { $0.path == "cache/" && $0.flags.contains(.ignored) })

                // ON: each ignored file is reported individually.
                let on = Repository.StatusOptions(flags: [.includeIgnored, .recurseUntrackedDirs, .recurseIgnoredDirs])
                let onEntries = try repo.statusEntries(options: on)
                let paths = Set(onEntries.map(\.path))
                #expect(paths.contains("cache/one.bin"))
                #expect(paths.contains("cache/two.bin"))
            }
        }

        @Test
        func statusEntries_renamesIndexToWorkdir_detectsRename() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "alpha.txt",
                    contents: String(repeating: "line\n", count: 100),
                    in: dir
                )
                // Stage a delete of alpha.txt, stage an add of beta.txt with same content.
                try TestFixture.deleteWorkdirFile("alpha.txt", in: dir)
                try TestFixture.writeWorkdirFile(
                    "beta.txt",
                    contents: String(repeating: "line\n", count: 100),
                    in: dir
                )
                let index = try repo.index()
                try index.removePath("alpha.txt")
                try index.addPath("beta.txt")
                try index.save()

                let opts = Repository.StatusOptions(flags: [.renamesHeadToIndex])
                let entries = try repo.statusEntries(options: opts)
                #expect(entries.contains { $0.flags.contains(.indexRenamed) })
            }
        }

        @Test
        func statusEntries_renameThreshold_varies() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                // Commit a 100-line file.
                let original = (0..<100).map { "line\($0)\n" }.joined()
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "alpha.txt", contents: original, in: dir
                )
                // Stage a rename where the new file has ~70% similarity with the
                // original (modify 30 lines out of 100).
                let modified = (0..<100).map { i in i < 30 ? "changed\(i)\n" : "line\(i)\n" }.joined()
                try TestFixture.deleteWorkdirFile("alpha.txt", in: dir)
                try TestFixture.writeWorkdirFile("beta.txt", contents: modified, in: dir)
                let index = try repo.index()
                try index.removePath("alpha.txt")
                try index.addPath("beta.txt")
                try index.save()

                // Threshold 50 (permissive): libgit2 detects the rename.
                let permissive = Repository.StatusOptions(
                    flags: [.renamesHeadToIndex], renameThreshold: 50
                )
                let permissiveEntries = try repo.statusEntries(options: permissive)
                #expect(permissiveEntries.contains { $0.flags.contains(.indexRenamed) })

                // Threshold 90 (strict): libgit2 rejects the rename because ~70%
                // < 90%. The entries appear as separate delete + add instead.
                let strict = Repository.StatusOptions(
                    flags: [.renamesHeadToIndex], renameThreshold: 90
                )
                let strictEntries = try repo.statusEntries(options: strict)
                #expect(!strictEntries.contains { $0.flags.contains(.indexRenamed) })
                #expect(strictEntries.contains { $0.path == "alpha.txt" && $0.flags.contains(.indexDeleted) })
                #expect(strictEntries.contains { $0.path == "beta.txt"  && $0.flags.contains(.indexNew) })
            }
        }

        @Test
        func statusEntries_baseline_overridesHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }
            try withTemporaryDirectory { dir in
                let repo = try TestFixture.makeSingleFileRepo(
                    path: "x.txt", contents: "v1", in: dir
                )
                // Second commit that changes x.txt to v2.
                try TestFixture.writeWorkdirFile("x.txt", contents: "v2", in: dir)
                let index = try repo.index()
                try index.addPath("x.txt")
                try index.save()
                let tree = try index.writeTree()
                _ = try repo.commit(
                    tree: tree, parents: [try repo.head().resolveToCommit()],
                    author: .test, message: "v2", updatingRef: "HEAD"
                )

                // HEAD tree == v2 tree. With baseline == HEAD's parent tree (v1 tree),
                // the scan compares workdir (v2) vs v1 and reports a modification.
                let head = try repo.head().resolveToCommit()
                let parents = try head.parents()
                let parent = try #require(parents.first)
                let parentTree = try parent.tree()

                let opts = Repository.StatusOptions(
                    flags: [.includeUntracked],  // no .includeIgnored so nothing spurious
                    baseline: parentTree
                )
                let entries = try repo.statusEntries(options: opts)
                // x.txt differs between baseline (v1) and current workdir (v2).
                #expect(entries.contains { $0.path == "x.txt" })
            }
        }
    }
}
