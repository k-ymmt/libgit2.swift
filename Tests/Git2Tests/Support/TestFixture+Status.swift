import Foundation
@testable import Git2

extension TestFixture {
    /// Writes `contents` to `.gitignore` at the repository root.
    static func writeGitignore(
        _ contents: String, in repoURL: URL
    ) throws {
        try writeWorkdirFile(".gitignore", contents: contents, in: repoURL)
    }

    /// Writes a UTF-8 text file at `relativePath` in the workdir, creating
    /// intermediate directories as needed.
    static func writeWorkdirFile(
        _ relativePath: String, contents: String, in repoURL: URL
    ) throws {
        let url = repoURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.data(using: .utf8)!.write(to: url)
    }

    /// Deletes a workdir file.
    static func deleteWorkdirFile(
        _ relativePath: String, in repoURL: URL
    ) throws {
        let url = repoURL.appendingPathComponent(relativePath)
        try FileManager.default.removeItem(at: url)
    }

    /// Creates a symlink at `linkRelativePath` pointing at `target` (raw
    /// string — may be relative to the link's directory, the way
    /// `ln -s target link` works).
    static func writeWorkdirSymlink(
        at linkRelativePath: String, target: String, in repoURL: URL
    ) throws {
        let url = repoURL.appendingPathComponent(linkRelativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            atPath: url.path, withDestinationPath: target
        )
    }

    /// Initializes a fresh non-bare repo at `dir`, writes `contents` to a
    /// single tracked file named `path`, stages it, and commits. Returns the
    /// open repository. Convenience factory for status tests that need a
    /// known HEAD commit with one known file.
    static func makeSingleFileRepo(
        path: String = "README.md",
        contents: String = "initial",
        in dir: URL
    ) throws -> Repository {
        let repo = try Repository.create(at: dir)
        try writeWorkdirFile(path, contents: contents, in: dir)
        let index = try repo.index()
        try index.addPath(path)
        let tree = try index.writeTree()
        _ = try repo.commit(
            tree: tree,
            parents: [],
            author: .test,
            message: "initial",
            updatingRef: "HEAD"
        )
        return repo
    }
}
