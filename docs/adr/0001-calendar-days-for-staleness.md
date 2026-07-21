# Staleness counts calendar days, not elapsed time

`isStale` compares days of silence against a per-status threshold, and the
boundary is strict (`> threshold`), so the definition of "day" decides real
outcomes. We count **calendar days in the local timezone** rather than elapsed
24-hour intervals, because the owner reasons in days ("three weeks of silence")
and the time component of `lastContactDate` is arbitrary — usually whatever a
date picker supplied.

## Consequences

Rows turn stale at local midnight, predictably, and two applications sent on the
same day always go stale on the same day regardless of the hour.

The cost is timezone dependence: travelling can move a row across the boundary a
day early or late. That is acceptable for a personal tracker, and strictly better
than staleness flipping mid-afternoon because of a timestamp the owner never saw.

The obvious implementation — subtracting two `Date`s, or `timeIntervalSince` —
gives elapsed time and is **wrong**. This is the deviation a future reader is
most likely to "fix". Use calendar-component arithmetic.
