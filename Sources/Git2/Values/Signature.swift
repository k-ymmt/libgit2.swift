import Cgit2
import Foundation

/// The author or committer attached to a commit — a snapshot of who made the change
/// and when, in which local time zone.
///
/// ``Signature`` is a value type. When read from a ``Commit``, libgit2's underlying
/// signature is copied into Swift storage so the value's lifetime is independent of
/// the commit handle.
public struct Signature: Sendable, Equatable {
    /// The display name (e.g. `"Alice Liddell"`).
    public let name: String

    /// The email address (e.g. `"alice@example.com"`).
    public let email: String

    /// The moment the signature was recorded, in UTC.
    public let date: Date

    /// The time zone the signature was recorded in.
    ///
    /// Git preserves the author's local offset separately from the UTC timestamp so
    /// tools can display dates in the original zone.
    public let timeZone: TimeZone

    /// Creates a signature from explicit fields.
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
        // TimeZone(secondsFromGMT:) returns nil only for offsets outside ±14h, which
        // Git itself does not produce. The UTC fallback is purely defensive.
        self.timeZone = TimeZone(secondsFromGMT: offsetSeconds)
            ?? TimeZone(secondsFromGMT: 0)!
    }
}
