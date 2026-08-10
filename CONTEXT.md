# Candido

Tracks the owner's own job applications, one company at a time, and surfaces the
ones that have gone quiet. `SPEC.md` is the contract; this file is the glossary.

## Where we are

**Current milestone: M5** — `/code-review` and `/security-review`: does the
reviewer catch what the owner cannot?

M4 closed as a **negative result**. Parallel subagents on independent tracks cost
more coordination than they returned for a solo owner, so the worktree machinery
is gone and only the export mirror (landed, #39) came out of the milestone;
`MenuBarExtra` was never built. See
`docs/adr/0003-parallel-tracks-cost-more-than-they-returned.md`.

`SPEC.md`'s milestone table says what each milestone *tests*; this line says
which one is *running*. Update it when a milestone ends.

Do not infer the milestone from branch names. This is history rather than a live
hazard: branches are now `<issue>-<slug>` with no prefix, but the script that
used to create them hardcoded `m2/`, so every branch between M2 ending on 22 Jul
and the script's deletion was misnamed, and those branches are still on the
remote. The number decides which score file a run lands in and which checklist
items the yardstick excludes from it, so a wrong guess still mis-scores the run —
reading the prefixes once put M4's delete work in a milestone that would have
excluded it.

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

### Correcting a name

**Rename**:
Correcting the name of a Company. The name identity is decided on moves with
the one that is displayed — fixing casing and fixing letters are one act. It is
a correction, not management: it is reached from a row, there is still no
company screen and no company list, and the Company it names is still one that
came into existence by being applied to. A Rename onto a name already taken is
a Merge.
_Avoid_: Edit, update, change, relabel

**Merge**:
What a Rename becomes when the name is already taken by another Company. The
Applications change hands, and the Company they left is Cleared away. Nothing
is Deleted — a Merge moves work, it never destroys it, which is why it is a
different word from Delete and asks a different question.
_Avoid_: Combine, consolidate, dedupe, fold

### Attention

**Stale**:
An Application that awaits their reply and has been silent for longer than its
Status allows. A property of the present moment only — never recorded, never
historical.
_Avoid_: Ghosted, overdue, cold, dormant

**Today**:
The day the window is deriving against: an instant, plus the calendar that
instant is read in. Every derived answer is relative to it, and it moves at
local midnight. The calendar is part of it, not context around it — the same
instant is two different days in two timezones, so an instant alone does not
name a day.
_Avoid_: Now, current date, clock

**Days of silence**:
The count of calendar days, in the owner's local timezone, between the last
contact and today. Not elapsed hours — time of day never affects whether an
Application is Stale.
_Avoid_: Age, elapsed time, days old

**Silence tolerated**:
How many days of silence a Status puts up with before an Application in it is
Stale. It belongs to the Status, not to the Application, and only a Status that
Awaits their reply has one — silence is not a problem when the next move is the
owner's or when the Application's Status is Terminal. `SPEC.md` sets the days
per Status and is the only place they live.
_Avoid_: Threshold, limit, timeout, grace period, deadline

**Standing**:
Whose move it is, and whether an Application is still in play. Every Status has
exactly one Standing — Awaits their reply, Awaits your move and Over are the
three Standings; Terminal and the silence a Status tolerates are read off them.
It is the classification of Status that decides behaviour: Tone also classifies
Status, but only for how the chip looks.
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

**Over**:
The Standing of a Status the Application does not move on from. Nobody owes
anybody a move, so an Application that stands Over can never be Stale, and it
is Archived rather than Active. Over is the Standing, not the Status — the
Status is Terminal.
_Avoid_: Closed, finished, dead, done

**Terminal**:
A Status the Application does not move on from: `rejected` or `withdrawn`.
Its Standing is Over. Terminal is the Status, not the Standing.
_Avoid_: Closed, finished, dead

### The chip

**Tone**:
How a Status reads in the Status column's chip, named as an appearance rather
than as a colour. A classification of Status alongside Standing, but a purely
visual one: it decides appearance and nothing else, so no rule about staleness,
filtering or Terminal is ever read off it. It refines Standing rather than
cutting across it — every Tone belongs to exactly one Standing, so two Statuses
sharing a Tone always share a Standing, and that much is tested. Which colour
each Tone renders as is `SPEC.md`'s enumerated list and not a rule to
generalise: only `applied` and `screening` are required to differ by shade, and
`interviewing`'s indigo promises nothing about hue tracking Standing. `pending`
is a word this glossary avoids for a Standing, reused here for an appearance.
_Avoid_: Style, theme, severity

**Shade**:
How pale a chip reads next to the others. The contract requires exactly one
shade difference — `applied` paler than `screening`, the pale and medium blues
— so Shade has two values and no more: pale, which is `applied` alone, and
standard, which is everything else. Standard is the absence of a required
difference, not a second point on a scale, and `interviewing` sits there
because its hue tells it apart. How much paler pale renders is not Shade: that
is an opacity, and it belongs to the view.
_Avoid_: Depth, level, intensity, weight

### Leaving the store

**Delete**:
The one act that destroys work: the owner removes an Application, and it is
gone. There is no undo and no trash, so it is always asked about first, in
words naming the row. Deleting is not archiving — an Archived Application is
still tracked, a deleted one no longer exists.
_Avoid_: Remove, discard, trash, archive

**Cleared away**:
What happens to a Company left holding nothing — by a Delete, or by an Import
filing its last Application under a different Company. A Company is not work:
it is never managed directly, exists only because something was applied for
there, and once empty it appears in no view while still being written to every
backup. One that still holds an Application is never cleared away.
_Avoid_: Deleted, pruned, orphaned, garbage collected

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
The Stale subset of Active. Always a subset, and structurally so — an
Application whose Status is Terminal stands Over, and only Awaits their reply
can go Stale.

**All**:
Every Application, Active and Archived alike.
