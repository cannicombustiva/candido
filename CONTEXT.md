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

**Awaits their reply**:
The property of a Status meaning the next move belongs to the company, not the
owner. Only such Applications can be Stale.
_Avoid_: Pending, open, waiting

**Terminal**:
A Status the Application does not move on from: `rejected` or `withdrawn`.
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
The Stale subset of Active. Always a subset — a Terminal Application never
awaits their reply, so it can never be Stale.

**All**:
Every Application, Active and Archived alike.
