import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// Today is the day the window is deriving against — one instant and the
/// calendar it is read in, travelling together.
///
/// The defect this suite guards is silent by construction: the window schedules
/// its wake-up against one calendar and derives its answers against another,
/// and in every timezone anyone has actually sat in the two agree. Nothing
/// throws, nothing logs, and the screen looks entirely plausible. The only way
/// to catch it is to assert that the instant the window wakes at and the
/// instant an Application turns Stale are the *same instant*, in timezones far
/// enough apart that no machine calendar could stand in for all of them.
/// Spread across roughly 28 hours of offset. Whatever calendar the machine
/// running this happens to have, it cannot be mistaken for all of these, so a
/// derivation that reached for `Calendar.current` instead of the one it was
/// handed fails here.
private let hostileZones = [
    "Europe/London", "Asia/Tokyo", "America/Sao_Paulo",
    "Pacific/Kiritimati", "Pacific/Niue",
]

@MainActor
@Suite struct TodayTests {
    private let store: TestStore

    init() throws {
        store = try TestStore()
    }

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    // MARK: - The regression witness

    /// The instant the window is woken at and the instant staleness flips are
    /// one instant, because both are read off one Today.
    ///
    /// An `applied` Application tolerates 21 days of silence, and the boundary
    /// is strict: at exactly 21 it is not yet Stale. So the moment it turns
    /// Stale is the moment the 22nd day begins — which is precisely the
    /// boundary the clock schedules. Scheduling in one calendar and deriving in
    /// another puts these two instants up to a day apart.
    @Test(arguments: hostileZones)
    func theBoundaryIsTheInstantStalenessFlips(zone: String) throws {
        let (today, application, calendar) = try onTheLastToleratedDay(in: zone)
        let boundary = DayBoundary.next(after: today)

        #expect(application.isStale(asOf: today) == false)
        #expect(
            application.isStale(
                asOf: Today(
                    instant: boundary.addingTimeInterval(-1), calendar: calendar)) == false)
        #expect(
            application.isStale(asOf: Today(instant: boundary, calendar: calendar)) == true)
    }

    /// The same claim for the Stale view: the row appears in it at the boundary
    /// and not one second before.
    @Test(arguments: hostileZones)
    func theStaleViewAdmitsTheRowAtTheBoundary(zone: String) throws {
        let (today, application, calendar) = try onTheLastToleratedDay(in: zone)
        let boundary = DayBoundary.next(after: today)

        #expect(ApplicationFilter.stale.narrow([application], asOf: today).isEmpty)
        #expect(
            ApplicationFilter.stale.narrow(
                [application],
                asOf: Today(instant: boundary.addingTimeInterval(-1), calendar: calendar)
            ).isEmpty)
        #expect(
            ApplicationFilter.stale.narrow(
                [application], asOf: Today(instant: boundary, calendar: calendar)
            ).count == 1)
    }

    // MARK: - The value itself

    @Test func carriesTheInstantAndTheCalendarItIsReadIn() {
        let london = calendar("Europe/London")
        let instant = london.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 12))!

        let today = Today(instant: instant, calendar: london)

        #expect(today.instant == instant)
        #expect(today.calendar.timeZone == TimeZone(identifier: "Europe/London")!)
    }

    /// The same instant read in two timezones is two different days, which is
    /// the whole reason the calendar has to travel with the instant rather than
    /// being picked up wherever the answer happens to be computed.
    @Test func isTwoDifferentDaysForOneInstantInTwoTimezones() {
        let london = calendar("Europe/London")
        let instant = london.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 23))!

        let inLondon = Today(instant: instant, calendar: london)
        let inTokyo = Today(instant: instant, calendar: calendar("Asia/Tokyo"))

        #expect(inLondon.startOfDay != inTokyo.startOfDay)
        #expect(DayBoundary.next(after: inTokyo) > DayBoundary.next(after: inLondon))
    }

    // MARK: - The entry points accept it

    /// Days of silence counted against a Today match the same count against the
    /// pair it replaces. Signatures move; the answers do not.
    @Test(arguments: [0, 1, 10, 14, 21, 22, 60])
    func countsTheSameDaysOfSilenceAsThePairItReplaces(days: Int) throws {
        let application = try store.application(silentFor: days)
        let today = TestClock.today

        #expect(application.daysOfSilence(asOf: today) == days)
        #expect(
            application.daysOfSilence(asOf: today)
                == application.daysOfSilence(asOf: today.instant, in: today.calendar))
    }

    @Test(arguments: [ApplicationFilter.all, .active, .stale, .archived])
    func narrowsTheSameWayAsThePairItReplaces(filter: ApplicationFilter) throws {
        let today = TestClock.today
        try store.application(company: "Spotify", status: .applied, silentFor: 30)
        try store.application(company: "Monzo", status: .offer, silentFor: 90)
        try store.application(company: "Deliveroo", status: .rejected, silentFor: 2)
        let applications = try store.applications()

        #expect(
            filter.narrow(applications, asOf: today).map(\.id)
                == filter.narrow(applications, asOf: today.instant, in: today.calendar)
                    .map(\.id))
    }

    /// `DayBoundary` keeps both its guarantees when handed a Today: the day's
    /// first instant rather than literally 00:00, and strictly later than the
    /// instant it was asked about even when that instant *is* a boundary.
    @Test func schedulesTheDaysFirstInstantStrictlyAhead() {
        let saoPaulo = calendar("America/Sao_Paulo")
        let midnightless = Today(
            instant: saoPaulo.date(from: DateComponents(year: 2018, month: 11, day: 3, hour: 12))!,
            calendar: saoPaulo)

        let boundary = DayBoundary.next(after: midnightless)

        #expect(
            boundary
                == saoPaulo.date(from: DateComponents(year: 2018, month: 11, day: 4, hour: 1))!)
        #expect(boundary > midnightless.instant)
        #expect(
            DayBoundary.next(after: Today(instant: boundary, calendar: saoPaulo)) > boundary)
        #expect(DayBoundary.secondsUntilNext(after: midnightless) > 0)
    }

    // MARK: - Helpers

    /// A Today in `zone`, and an `applied` Application standing on exactly the
    /// 21 days of silence that Status tolerates — so it is not yet Stale, and
    /// the next boundary is the moment it becomes Stale.
    private func onTheLastToleratedDay(
        in zone: String
    ) throws -> (today: Today, application: Application, calendar: Calendar) {
        let calendar = calendar(zone)
        let today = Today(
            instant: calendar.date(
                from: DateComponents(year: 2026, month: 7, day: 21, hour: 12))!,
            calendar: calendar)
        return (today, try applicationSilent(for: 21, asOf: today), calendar)
    }

    /// An `applied` Application whose last contact was exactly `days` calendar
    /// days before `today`, in `today`'s own calendar.
    private func applicationSilent(for days: Int, asOf today: Today) throws -> Application {
        let lastContact = today.calendar.date(
            byAdding: .day, value: -days, to: today.instant)!
        return try Application.create(
            companyNamed: "Spotify",
            title: "iOS Engineer",
            status: .applied,
            appliedDate: lastContact,
            lastContactDate: lastContact,
            in: store.context
        )
    }
}
