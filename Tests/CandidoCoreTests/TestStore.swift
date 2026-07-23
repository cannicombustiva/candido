import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// The clock every suite runs against.
///
/// Staleness counts calendar days in the local timezone
/// (`docs/adr/0001-calendar-days-for-staleness.md`), so a suite that used the
/// machine's calendar and a real "now" would be asserting something different
/// depending on where the machine is standing and what time it is run. Both are
/// pinned here, once, so every suite means the same thing on every machine.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// Midday on a fixed date. Nothing in staleness may depend on the hour,
    /// and several tests prove it by varying the hour around this.
    static let now: Date = calendar.date(
        from: DateComponents(year: 2026, month: 7, day: 21, hour: 12))!

    /// A moment `daysAgo` calendar days before `now`, at the given hour.
    static func date(daysAgo: Int, atHour hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }
}

/// An empty in-memory store, and the one way tests put Applications into it.
///
/// The container is built from `CandidoCore.models`, the same list the app
/// builds its own from, so the schema under test cannot drift from the shipped
/// one. Every date it stores comes from `TestClock`.
@MainActor
struct TestStore {
    let context: ModelContext

    init() throws {
        let container = try ModelContainer(
            for: Schema(CandidoCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    /// Adds an Application that has been silent for `days` calendar days as of
    /// `TestClock.now`.
    ///
    /// `appliedDaysAgo` defaults to the same day as the last contact, which is
    /// what `Application.create` itself does. Pass it only when the two dates
    /// need to differ — the "interviewed yesterday, applied 60 days ago" case.
    @discardableResult
    func application(
        company: String = "Spotify",
        title: String = "iOS Engineer",
        status: Status = .applied,
        silentFor days: Int = 0,
        atHour hour: Int = 12,
        appliedDaysAgo: Int? = nil,
        jobURL: URL? = nil
    ) throws -> Application {
        try Application.create(
            companyNamed: company,
            title: title,
            status: status,
            appliedDate: TestClock.date(daysAgo: appliedDaysAgo ?? days),
            lastContactDate: TestClock.date(daysAgo: days, atHour: hour),
            jobURL: jobURL,
            in: context
        )
    }

    /// Everything in the store, in no particular order — an unsorted
    /// `FetchDescriptor` promises none, so callers sort.
    func applications() throws -> [Application] {
        try context.fetch(FetchDescriptor<Application>())
    }
}
