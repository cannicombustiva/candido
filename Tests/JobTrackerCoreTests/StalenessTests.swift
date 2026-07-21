import Foundation
import SwiftData
import Testing

@testable import JobTrackerCore

/// Staleness is the one rule the owner cannot check by looking at the app —
/// a wrong threshold or a `>=` in place of `>` produces a screen that looks
/// entirely plausible and is wrong.
@MainActor
@Suite struct StalenessTests {
    /// A fixed timezone, so the suite means the same thing on any machine.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// Midday on a fixed date. Nothing in staleness may depend on the hour,
    /// and several tests below prove it.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 12))!
    }

    private func date(_ daysBeforeNow: Int, atHour hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysBeforeNow, to: now)!
        return calendar.date(
            bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func application(
        _ status: Status,
        lastContact daysAgo: Int,
        atHour hour: Int = 12,
        appliedDaysAgo: Int? = nil
    ) throws -> Application {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        return try Application.create(
            companyNamed: "Spotify",
            title: "iOS Engineer",
            status: status,
            appliedDate: date(appliedDaysAgo ?? daysAgo),
            lastContactDate: date(daysAgo, atHour: hour),
            in: context
        )
    }

    // MARK: - Which statuses can go stale at all

    @Test(arguments: [Status.applied, .screening, .interviewing])
    func waitsOnTheirReply(_ status: Status) {
        #expect(status.awaitsTheirReply)
    }

    /// An `offer` is the owner's move, and the two terminal statuses are over.
    /// None of them can ever be Stale, however long the silence.
    @Test(arguments: [Status.offer, .rejected, .withdrawn])
    func doesNotWaitOnTheirReply(_ status: Status) throws {
        #expect(!status.awaitsTheirReply)

        let application = try application(status, lastContact: 500)

        #expect(!application.isStale(asOf: now, in: calendar))
    }

    // MARK: - The boundary, per status

    /// The spec's exact wording: "At exactly 21 days an `applied` row is *not*
    /// stale. At 22 days it is." Both sides, for every status that can go stale.
    @Test(arguments: [
        (Status.applied, 21),
        (Status.screening, 14),
        (Status.interviewing, 10),
    ])
    func isNotStaleAtExactlyItsThreshold(status: Status, threshold: Int) throws {
        #expect(status.stalenessThreshold == threshold)

        let atThreshold = try application(status, lastContact: threshold)
        #expect(!atThreshold.isStale(asOf: now, in: calendar))

        let dayBefore = try application(status, lastContact: threshold - 1)
        #expect(!dayBefore.isStale(asOf: now, in: calendar))
    }

    @Test(arguments: [
        (Status.applied, 22),
        (Status.screening, 15),
        (Status.interviewing, 11),
    ])
    func isStaleOneDayPastItsThreshold(status: Status, days: Int) throws {
        let application = try application(status, lastContact: days)

        #expect(application.isStale(asOf: now, in: calendar))
    }

    /// The thresholds differ on purpose — silence after a final interview is
    /// louder than silence after applying. At 15 days of silence, screening
    /// and interviewing are stale and applied is not.
    @Test func appliesADifferentThresholdPerStatus() throws {
        let days = 15

        #expect(!(try application(.applied, lastContact: days).isStale(asOf: now, in: calendar)))
        #expect(try application(.screening, lastContact: days).isStale(asOf: now, in: calendar))
        #expect(
            try application(.interviewing, lastContact: days).isStale(asOf: now, in: calendar))
    }

    // MARK: - Calendar days, not elapsed time

    /// Two applications contacted on the same calendar day agree about
    /// staleness whatever the hour — the elapsed-time implementation this ADR
    /// warns about would put 09:00 and 22:00 on opposite sides of the line.
    @Test func ignoresTheTimeOfDay() throws {
        let morning = try application(.applied, lastContact: 22, atHour: 9)
        let night = try application(.applied, lastContact: 22, atHour: 22)

        #expect(morning.isStale(asOf: now, in: calendar))
        #expect(night.isStale(asOf: now, in: calendar))
        #expect(
            morning.daysOfSilence(asOf: now, in: calendar)
                == night.daysOfSilence(asOf: now, in: calendar))
    }

    /// Contact late yesterday and "now" early today is one calendar day of
    /// silence, not zero, however few hours have actually elapsed.
    @Test func countsTheBoundaryCrossedAtMidnight() throws {
        let lateYesterday = try application(.applied, lastContact: 1, atHour: 23)
        let earlyThisMorning = calendar.date(
            bySettingHour: 1, minute: 0, second: 0, of: now)!

        #expect(lateYesterday.daysOfSilence(asOf: earlyThisMorning, in: calendar) == 1)
    }

    /// Spanning a spring-forward loses an hour of elapsed time. Counting
    /// elapsed intervals would report 10 days here and call the Application
    /// fresh; calendar days report 11 and call it Stale. This is the exact
    /// deviation ADR 0001 says a future reader is most likely to introduce.
    @Test func isUnaffectedByADaylightSavingTransition() throws {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        // Europe/London moves to BST on 29 March 2026.
        let beforeTheClockChange = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 25, hour: 12))!
        let afterTheClockChange = calendar.date(
            from: DateComponents(year: 2026, month: 4, day: 5, hour: 12))!
        let application = try Application.create(
            companyNamed: "Spotify",
            title: "iOS Engineer",
            status: .interviewing,
            appliedDate: beforeTheClockChange,
            lastContactDate: beforeTheClockChange,
            in: context
        )

        #expect(
            application.daysOfSilence(asOf: afterTheClockChange, in: calendar) == 11)
        #expect(application.isStale(asOf: afterTheClockChange, in: calendar))
    }

    @Test func countsTodayAsNoSilenceAtAll() throws {
        let contactedToday = try application(.applied, lastContact: 0, atHour: 8)

        #expect(contactedToday.daysOfSilence(asOf: now, in: calendar) == 0)
        #expect(!contactedToday.isStale(asOf: now, in: calendar))
    }

    // MARK: - The clock runs from the last contact

    /// The spec's failure case: "A company that interviewed me yesterday must
    /// never read as stale because I applied 60 days ago."
    @Test func measuresFromTheLastContactNotTheAppliedDate() throws {
        let application = try application(
            .interviewing, lastContact: 1, appliedDaysAgo: 60)

        #expect(!application.isStale(asOf: now, in: calendar))
        #expect(application.daysOfSilence(asOf: now, in: calendar) == 1)
    }

    /// And the reverse: a fresh application whose silence has run long is
    /// stale even though it was only sent recently.
    @Test func goesStaleOnSilenceAloneWhateverTheAppliedDate() throws {
        let application = try application(.interviewing, lastContact: 11)

        #expect(application.isStale(asOf: now, in: calendar))
    }
}
