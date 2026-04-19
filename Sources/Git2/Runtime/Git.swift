public enum Git {
    public static func bootstrap() throws(GitError) {
        try GitRuntime.shared.bootstrap()
    }

    public static func shutdown() throws(GitError) {
        try GitRuntime.shared.shutdown()
    }

    public static var isBootstrapped: Bool {
        GitRuntime.shared.isBootstrapped
    }

    public static var version: Version {
        Version.current
    }
}
