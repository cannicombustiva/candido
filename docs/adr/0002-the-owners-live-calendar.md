# The window tracks the owner's live calendar

`DayClock` builds every Today the window sees from `Calendar.autoupdatingCurrent`
— a calendar that follows the machine's timezone as it changes, rather than a
snapshot taken when the window opened. That one choice decides both halves of
the behaviour, because the same value schedules the next boundary and derives
every answer shown against it.

## Why

An owner who changes timezone mid-session should get *their* midnight, not the
one they flew out of. `0001-calendar-days-for-staleness.md` already accepts
timezone dependence as the cost of counting calendar days; a frozen calendar
would not remove that cost, it would only make the app disagree with the clock
in the menu bar. A long-lived window — this one is meant to stay open — outlives
the timezone it was opened in.

## Why it is written down

`autoupdatingCurrent` looks like an over-cautious choice next to `.current`, and
it is exactly the kind of thing a future reader simplifies away. It is not
cosmetic. It is the reason the divergence in #23 mattered: `DayClock` scheduled
against the live calendar while the Stale view and the styled last-contact
column derived against the calendar default. The window woke at the new
midnight and re-derived against the old one — no error, no log, nothing in the
tests that would notice.

The fix was to make the app hold one Today rather than to freeze the calendar.
`Today` carries the instant and the calendar as one value, `DayClock` owns the
only one, and both views read it. Reverting to a fixed calendar would trade a
real behaviour for the appearance of determinism.

## Consequences

Scheduling and derivation cannot run in different timezones: there is one
calendar and it reaches both through one value.

A timezone change does not itself wake the window — the pending sleep was
scheduled against the old boundary and runs to that instant. The window is at
most one boundary behind after a change, and re-derives correctly from then on.
Waking on timezone-change notifications is a possible future refinement, not a
correctness gap in the day maths.

Tests must never accept a calendar default in place of a stated one. Suites pass
a Today built from an explicit calendar; `TodayTests` asserts the claim across
timezones spread far enough apart that no machine calendar could stand in for
all of them.
