import Cgit2
import Foundation

public struct Signature: Sendable, Equatable {
    public let name: String
    public let email: String
    public let date: Date
    public let timeZone: TimeZone

    public init(name: String, email: String, date: Date, timeZone: TimeZone) {
        self.name = name
        self.email = email
        self.date = date
        self.timeZone = timeZone
    }

    internal init(copyingFrom raw: UnsafePointer<git_signature>) {
        self.name = String(cString: raw.pointee.name)
        self.email = String(cString: raw.pointee.email)
        self.date = Date(timeIntervalSince1970: TimeInterval(raw.pointee.when.time))
        let offsetSeconds = Int(raw.pointee.when.offset) * 60
        self.timeZone = TimeZone(secondsFromGMT: offsetSeconds)
            ?? TimeZone(secondsFromGMT: 0)!
    }
}
