import Testing
@testable import Git2

@Suite
struct TreeBuilderEntryTests {
    @Test
    func fieldsRoundTripThroughInit() throws {
        let oid = try OID(hex: "0000000000000000000000000000000000000001")
        let entry = TreeBuilderEntry(
            name: "README.md",
            oid: oid,
            filemode: .blob
        )
        #expect(entry.name == "README.md")
        #expect(entry.oid == oid)
        #expect(entry.filemode == .blob)
    }

    @Test
    func equatableByAllFields() throws {
        let oid = try OID(hex: "0000000000000000000000000000000000000001")
        let a = TreeBuilderEntry(name: "a", oid: oid, filemode: .blob)
        let b = TreeBuilderEntry(name: "a", oid: oid, filemode: .blob)
        let c = TreeBuilderEntry(name: "a", oid: oid, filemode: .blobExecutable)
        #expect(a == b)
        #expect(a != c)
    }
}
