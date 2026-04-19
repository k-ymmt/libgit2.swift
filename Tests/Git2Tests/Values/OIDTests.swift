import Testing
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct OIDTests {
        @Test
        func oidRoundtripsHex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            let hex = "0123456789abcdef0123456789abcdef01234567"
            let oid = try OID(hex: hex)
            #expect(oid.hex == hex)
            #expect(oid.description == hex)
        }

        @Test
        func oidLengthIs20() {
            #expect(OID.length == 20)
        }

        @Test
        func oidEqualityIsByValue() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            let a = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
            let b = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
            let c = try OID(hex: "fedcba9876543210fedcba9876543210fedcba98")
            #expect(a == b)
            #expect(a != c)
        }

        @Test
        func oidIsHashable() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            let a = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
            let b = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
            var set = Set<OID>()
            set.insert(a)
            set.insert(b)
            #expect(set.count == 1)
        }

        @Test
        func oidFromShortHexThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            #expect(throws: GitError.self) {
                _ = try OID(hex: "deadbeef")
            }
        }

        @Test
        func oidFromNonHexThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            #expect(throws: GitError.self) {
                _ = try OID(hex: "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz")
            }
        }

        @Test
        func oidRejectsShorterThan40Hex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            // 39 valid hex chars must still throw after the fromstrn migration.
            #expect(throws: GitError.self) {
                _ = try OID(hex: "0123456789abcdef0123456789abcdef0123456")
            }
        }

        @Test
        func oidRejectsLongerThan40Hex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            // 41 chars — above the SHA-1 hex width.
            #expect(throws: GitError.self) {
                _ = try OID(hex: "0123456789abcdef0123456789abcdef0123456789")
            }
        }

        @Test
        func oidZeroIsAllZeroBytes() {
            let zero = OID.zero
            #expect(zero.hex == String(repeating: "0", count: 40))
        }

        @Test
        func oidZeroEqualsItself() {
            #expect(OID.zero == OID.zero)
        }
    }
}
