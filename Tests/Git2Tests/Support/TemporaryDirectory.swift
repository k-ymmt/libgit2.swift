import Foundation

func withTemporaryDirectory<T>(_ body: (URL) throws -> T) rethrows -> T {
    let base = URL.temporaryDirectory
        .appendingPathComponent("Git2Tests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    return try body(base)
}

func withTemporaryDirectoryAsync<R>(
    _ body: (URL) async throws -> R
) async throws -> R {
    let base = URL.temporaryDirectory
        .appendingPathComponent("Git2Tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    return try await body(base)
}
