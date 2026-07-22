# Job Application Tracker

Tracks the owner's own job applications, one company at a time, and surfaces the
ones that have gone quiet. `SPEC.md` is the contract; this file is the glossary.

## Language

### Core entities

**Company**:
An organization the owner has applied to. Identified by name, never managed
directly by the owner — it comes into existence the first time it is named.
_Avoid_: Employer, org, account

**Application**:
One pursuit of one role at one Company. The unit everything else is about.
_Avoid_: Job, role, position, lead

**Status**:
Where an Application currently stands: `applied`, `screening`, `interviewing`,
`offer`, `rejected`, or `withdrawn`.
_Avoid_: State, stage, phase

### Attention

**Stale**:
An Application that awaits their reply and has been silent for longer than its
Status allows. A property of the present moment only — never recorded, never
historical.
_Avoid_: Ghosted, overdue, cold, dormant

**Days of silence**:
The count of calendar days, in the owner's local timezone, between the last
contact and today. Not elapsed hours — time of day never affects whether an
Application is Stale.
_Avoid_: Age, elapsed time, days old

**Standing**:
Whose move it is, and whether an Application is still in play. Every Status has
exactly one Standing, and it is the only classification of Status there is —
Awaits their reply, Terminal and the staleness thresholds are all read off it.
_Avoid_: State, category, kind

**Awaits their reply**:
The Standing of a Status meaning the next move belongs to the company, not the
owner. It carries the days of silence that Status tolerates. Only such
Applications can be Stale.
_Avoid_: Pending, open, waiting

**Awaits your move**:
The Standing of `offer`: still live, but the owner is the one who owes an
answer, so it can never be Stale.
_Avoid_: Pending, action required

**Terminal**:
A Status the Application does not move on from: `rejected` or `withdrawn`.
Its Standing is Over.
_Avoid_: Closed, finished, dead

### Views

The four ways the Application list is narrowed. All are derived from Status —
none is a stored flag, and an Application is never "put into" one.

**Active**:
Applications whose Status is not Terminal: `applied`, `screening`,
`interviewing`, `offer`. An `offer` is Active — the pursuit is still live, the
next move is simply the owner's.
_Avoid_: Open, in progress, live

**Archived**:
Applications whose Status is Terminal. The only way an Application becomes
Archived is by being `rejected` or `withdrawn`; there is no separate act of
archiving.
_Avoid_: Closed, hidden, done, inactive

**Stale (view)**:
The Stale subset of Active. Always a subset, and structurally so — a Terminal
Application stands Over, and only Awaits their reply can go Stale.

**All**:
Every Application, Active and Archived alike.
