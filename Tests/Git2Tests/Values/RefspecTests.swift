import Testing
@testable import Git2

struct RefspecTests {
    @Test func initializer_roundTrips() {
        let r = Refspec("+refs/heads/*:refs/remotes/origin/*")
        #expect(r.string == "+refs/heads/*:refs/remotes/origin/*")
    }

    @Test func equatable_sameStringEqual() {
        #expect(Refspec("refs/heads/main") == Refspec("refs/heads/main"))
    }

    @Test func equatable_differentStringUnequal() {
        #expect(Refspec("refs/heads/main") != Refspec("refs/heads/dev"))
    }

    @Test func hashable_sameStringSameHash() {
        var seen: Set<Refspec> = []
        seen.insert(Refspec("refs/heads/main"))
        seen.insert(Refspec("refs/heads/main"))
        #expect(seen.count == 1)
    }
}
