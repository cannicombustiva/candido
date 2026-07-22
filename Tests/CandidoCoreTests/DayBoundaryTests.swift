import Foundation
import Testing

@testable import CandidoCore

/// Staleness answers change at local midnight and at no other moment, so a
/// window left open overnight has to be told when the next one is. Getting
/// this wrong is invisible: the app simply keeps showing yesterday's answer.
@Suite struct DayBoundaryTests {
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func date(
        _ calendar: Calendar,
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year, month: month, day: day,
                hour: hour, minute: minute, second: second))!
    }

    @Test func isTheFirstInstantOfTomorrow() {
        let now = date(london, 2026, 7, 21, 12)

        #expect(DayBoundary.next(after: now, in: london) == date(london, 2026, 7, 22))
    }

    /// Standing exactly on a boundary, the next one is tomorrow's — never the
    /// present instant. A boundary that returned `now` would schedule a timer
    /// with no delay and spin.
    @Test func isNeverTheInstantItIsAskedAbout() {
        let midnight = date(london, 2026, 7, 21)

        #expect(DayBoundary.next(after: midnight, in: london) == date(london, 2026, 7, 22))
        #expect(DayBoundary.next(after: midnight, in: london) > midnight)
    }

    @Test func isOneSecondAwayAtTheLastSecondOfTheDay() {
        let now = date(london, 2026, 7, 21, 23, 59, 59)

        #expect(DayBoundary.next(after: now, in: london) == date(london, 2026, 7, 22))
        #expect(DayBoundary.secondsUntilNext(after: now, in: london) == 1)
    }

    /// The owner's timezone decides, not the machine's or UTC's. At 23:00 in
    /// London on this date it is already tomorrow in Tokyo, so Tokyo's next
    /// boundary is a whole day further along the timeline.
    @Test func followsTheCalendarsTimezone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = date(london, 2026, 7, 21, 23)

        #expect(DayBoundary.next(after: now, in: london) == date(london, 2026, 7, 22))
        #expect(DayBoundary.next(after: now, in: tokyo) == date(tokyo, 2026, 7, 23))
        #expect(
            DayBoundary.next(after: now, in: tokyo)
                > DayBoundary.next(after: now, in: london))
    }

    /// A spring-forward day is 23 hours long, and the boundary must land on the
    /// day's real end, not 24 hours later. Europe/London moves to BST at 01:00
    /// on 29 March 2026, so the 29th starts at 00:00 GMT and ends 23 hours on.
    @Test func lands23HoursLaterAcrossASpringForward() {
        let now = date(london, 2026, 3, 29, 12)

        #expect(DayBoundary.next(after: now, in: london) == date(london, 2026, 3, 30))
        #expect(
            DayBoundary.secondsUntilNext(after: date(london, 2026, 3, 29), in: london)
                == 23 * 3600)
    }

    /// And an autumn day is 25 hours long. Adding a fixed 86,400 seconds would
    /// fire an hour early here and an hour late in March.
    @Test func lands25HoursLaterAcrossAFallBack() {
        #expect(
            DayBoundary.secondsUntilNext(after: date(london, 2026, 10, 25), in: london)
                == 25 * 3600)
    }

    /// Some timezones have no midnight at all on the day they change over:
    /// São Paulo's old DST rule jumped 23:59:59 straight to 01:00, so 4
    /// November 2018 begins at 01:00. The boundary is the day's first instant,
    /// whatever the clock calls it.
    @Test func usesTheDaysFirstInstantWhereMidnightDoesNotExist() {
        var saoPaulo = Calendar(identifier: .gregorian)
        saoPaulo.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let now = date(saoPaulo, 2018, 11, 3, 12)

        let boundary = DayBoundary.next(after: now, in: saoPaulo)

        #expect(boundary == date(saoPaulo, 2018, 11, 4, 1))
        #expect(saoPaulo.component(.day, from: boundary) == 4)
    }

    /// Every boundary is in the future by construction — the app schedules a
    /// timer on this number and a negative one would fire immediately, forever.
    @Test(arguments: [0, 1, 6, 12, 23])
    func isAlwaysAheadOfTheInstantItIsAskedAbout(hour: Int) {
        let now = date(london, 2026, 10, 25, hour, 30)

        #expect(DayBoundary.next(after: now, in: london) > now)
        #expect(DayBoundary.secondsUntilNext(after: now, in: london) > 0)
    }
}
