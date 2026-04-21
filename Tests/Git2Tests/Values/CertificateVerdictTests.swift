import Testing
@testable import Git2

struct CertificateVerdictTests {
    @Test func acceptIsDistinct() {
        #expect(CertificateVerdict.accept != .reject)
        #expect(CertificateVerdict.accept != .passthrough)
    }

    @Test func rejectIsDistinct() {
        #expect(CertificateVerdict.reject != .passthrough)
    }

    @Test func allCasesRoundTripEquatable() {
        #expect(CertificateVerdict.accept       == .accept)
        #expect(CertificateVerdict.reject       == .reject)
        #expect(CertificateVerdict.passthrough  == .passthrough)
    }
}
