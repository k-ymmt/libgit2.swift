import Cgit2
import Foundation

extension Repository {
    /// Finds the `.git` directory of a repository by walking up from `url`.
    ///
    /// - Parameters:
    ///   - url: The starting directory (or a file inside the working tree).
    ///   - acrossFilesystems: If `false` (default), stop searching when the
    ///     walk would cross a filesystem mount point. If `true`, keep going.
    ///   - ceilingDirectories: Directories at which to halt the walk. The
    ///     search stops when it reaches any of these.
    /// - Returns: The URL of the discovered `.git` directory (or the root of
    ///   a bare repository).
    /// - Throws: ``GitError``. ``GitError/Code/notFound`` when no repository
    ///   is found before hitting a ceiling or a filesystem boundary.
    public static func discover(
        startingAt url: URL,
        acrossFilesystems: Bool = false,
        ceilingDirectories: [URL] = []
    ) throws(GitError) -> URL {
        GitRuntime.shared.requireBootstrapped()

        var buf = git_buf()
        defer { git_buf_dispose(&buf) }

        // libgit2 expects a single ":"-separated (or ";" on Windows) path list.
        let ceilingString = ceilingDirectories.map(\.path).joined(separator: ":")

        let result: Int32 = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return GIT_EINVALIDSPEC.rawValue }
            if ceilingString.isEmpty {
                return git_repository_discover(&buf, path, acrossFilesystems ? 1 : 0, nil)
            }
            return ceilingString.withCString { ceiling in
                git_repository_discover(&buf, path, acrossFilesystems ? 1 : 0, ceiling)
            }
        }
        try check(result)
        // libgit2 contract on GIT_OK: buf.ptr non-NULL and NUL-terminated.
        return URL(fileURLWithPath: String(cString: buf.ptr), isDirectory: true)
    }

    /// Convenience: discovers a repository and opens it in one call.
    public static func open(
        discoveringFrom url: URL,
        acrossFilesystems: Bool = false,
        ceilingDirectories: [URL] = []
    ) throws(GitError) -> Repository {
        let gitDir = try Repository.discover(
            startingAt: url,
            acrossFilesystems: acrossFilesystems,
            ceilingDirectories: ceilingDirectories
        )
        return try Repository.open(at: gitDir)
    }
}
