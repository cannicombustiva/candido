# Candido — Spec

Candido is a macOS app for tracking my own job applications.

**This document is the contract.** Implementation is agent-written; this file is
hand-written and is the source of truth. When code and this document disagree,
the code is wrong.

## Goals, in priority order

1. **Explore agent workflows.** The app is a backdrop for testing how far
   different agent-driving techniques go. The process is the deliverable.
2. **Be genuinely useful.** I track real applications here. If it isn't in daily
   use by M3, the later experiments have no ground truth.
3. **CV artifact.** Aspirational, not a driver. Nothing is chosen for this reason
   alone.

I am a frontend dev. I do not read the Swift. Verification does not come from my
eyes on the diff — see [Verification](#verification).

## Stack

| Decision | Choice | Why |
| --- | --- | --- |
| Platform | macOS, SwiftUI | Unfamiliar language is a better agent testbed — no falling back on fixing it myself |
| Persistence | SwiftData, local only | Platform-native; no paid Apple account, so no CloudKit |
| Structure | `CandidoCore` Swift package + thin app target | `swift test` runs in seconds with clean output — the agent feedback loop |
| Backup | One-way JSON mirror to a user-chosen folder | Point it at Google Drive; no OAuth, no SDK, no paid account |

No paid Apple Developer account. Consequences: no CloudKit sync, no
notarized distribution, repo is the deliverable. `@Attribute(.unique)` is
available (CloudKit would have forbidden it).

## Domain model

Two `@Model` types, both in `CandidoCore`.

### Company

| Field | Type | Notes |
| --- | --- | --- |
| `name` | `String` | Unique |
| `applications` | `[Application]` | One-to-many, inverse of `Application.company` |

Companies are never managed directly by the user. There is no "manage companies"
screen and no company list. Typing a new name in the add sheet silently creates
one.

**Find-or-create is case- and whitespace-insensitive.** `"spotify"`,
`"Spotify"`, and `" Spotify "` all resolve to the same `Company`. The unique
constraint alone does not do this — it is logic in the package, and it is
unit-tested. First spelling entered wins as the stored display name, and goes
on winning until the name is renamed.

#### Renaming corrects a name. It is not managing a Company

A name typed once with a typo in it is otherwise that name forever — in the
table and in every backup. So the inspector offers **Rename…** on the Company
the selected row is filed under, and that is the whole of it: no company screen,
no list, a correction reachable from a row. The dialog says how many
Applications share the name, because the panel it opens from is one
Application's and the name is not.

A rename writes both the display name and the folded name identity is decided
on. Fixing casing and fixing letters are one act, not two. A blank name is
refused, by the same rule the add sheet obeys. A name that folds to the Company's
own identity only rewrites what is displayed.

**A rename onto a name already taken is a merge**, and is confirmed as one, in
words naming both Companies and the count. The Applications change hands, the
emptied Company is cleared away by the rule below, and nothing is deleted.
Refusing the rename instead would break it in the case that motivates it: you
notice the typo because you typed the name correctly the second time, so the
good spelling is already in the store.

Import does not know a rename happened. A backup written before one still names
the old Company, and importing it re-creates that Company and takes its
Applications back. That is the price already paid for an import that merges and
never deletes — the store can only grow.

### Application

| Field | Type | Notes |
| --- | --- | --- |
| `company` | `Company` | Relationship |
| `title` | `String` | Free text. Surrounding whitespace is trimmed; nothing else is normalized — no case-folding, no collapsing of interior spaces, no deduplication, no entity. Titles are too messy to be worth one |
| `status` | `Status` | See below |
| `appliedDate` | `Date` | Set once, never changes |
| `lastContactDate` | `Date` | Resets whenever either side makes contact, and a status change is contact — see below. Drives staleness |
| `jobURL` | `URL?` | Postings vanish; I want to reread the JD before a call |
| `notes` | `String` | Free text |

Deferred to v2: `source` (LinkedIn / referral / direct / recruiter-inbound).
It only pays off after ~30 applications and makes a clean increment.

Explicitly rejected: `salary` (usually unknown at apply time, field stays empty
and drags the UI down), `nextActionDate` (duplicates staleness — two competing
notions of "needs attention" is one too many).

## Status and staleness

### Statuses

`applied` · `screening` · `interviewing` · `offer` · `rejected` · `withdrawn`

### Changing a status is contact

Moving a row's status sets `lastContactDate` to today. Nearly every status
change happens because they wrote to me — a rejection, an invitation to screen,
an offer — and the date I care about is the date of that letter, not the date I
last remembered to touch the field.

**Except into `withdrawn`.** Withdrawing is my act alone. Nobody contacted
anybody, so nothing about the last contact changed. Moving *out* of `withdrawn`
stamps like any other change: something brought the pursuit back, and that
something came from them. A row revived after six months must not read as stale
the instant I revive it.

**The stamp is a default, not a lock.** The date picker sits under the status
picker in the inspector and still wins. I learn on Thursday that the rejection
came on Monday, and I drag it back — without that, this would make the date less
accurate than typing it by hand. Re-selecting the status a row already has is
not a change and does nothing.

**Only a change to an existing row stamps.** Creating an application does not:
`lastContactDate` still defaults to the applied date, because something sent 60
days ago has been silent for 60 days whatever status I file it under. Importing
a backup does not either — a round-trip through the JSON file that aged every
row to today would leave me with a backup that is not one.

Today here is the same today staleness derives against: a calendar day in my
local timezone. No time of day is stored, because no rule reads one.

A `rejected` row therefore carries the day I marked it, which is the day they
sent it. The last-contact column sorts oldest first, so such a row moves to the
end of it — either way the archived order is when I dealt with a row, not when I
first wrote. That is the answer I want from an archived row.

See `docs/adr/0007-a-status-change-is-contact.md`.

### Staleness is derived, never stored

There is no background job. Nothing mutates status behind my back. `isStale` is
computed on read, every time.

```
isStale = status awaits their reply, tolerating n days of silence, AND daysSince(lastContactDate) > n
```

**Silence tolerated is per-status.** Silence after a final interview is louder
than silence after applying.

| Status | Standing | Silence tolerated |
| --- | --- | --- |
| `applied` | awaits their reply | 21 days |
| `screening` | awaits their reply | 14 days |
| `interviewing` | awaits their reply | 10 days |
| `offer` | awaits your move | — (ball is in my court) |
| `rejected` | over | — (terminal) |
| `withdrawn` | over | — (terminal) |

**Boundary is strict.** `>` the tolerated silence, not `>=`. At exactly 21 days
an `applied` row is *not* stale. At 22 days it is.

**Days are calendar days in the local timezone**, not elapsed 24-hour intervals.
Rows turn stale at local midnight. Time of day is not part of the decision — two
applications sent on the same day go stale on the same day, whether one was sent
at 09:00 and the other at 22:00. See `docs/adr/0001-calendar-days-for-staleness.md`.

Clock runs from `lastContactDate`, not `appliedDate`. A company that interviewed
me yesterday must never read as stale because I applied 60 days ago.

No history. Staleness is a property of the present moment only — there is no
"went stale on Mar 3, then revived" record, no audit log, no event table.

## UI

Single window, `NavigationSplitView`:

- **Sidebar** — filters: All / Active / Stale / Archived
- **Content** — SwiftUI `Table`, sortable columns
- **Inspector** — `.inspector()` panel for the selected row: notes, URL, edit

Rules:

- **Status is a colored chip**, in the table and nowhere else. The word stays
  inside it — color alone is unreadable to half the people who might see my
  screen, and the column is a sort key. The colours are the contract, and they
  are these: `applied` pale blue, `screening` medium blue, `interviewing`
  indigo, `offer` green, `rejected` and `withdrawn` the same grey. Read them as
  a list, not as a rule. `rejected` and `withdrawn` share a grey on purpose — a
  visual difference would claim a distinction that does not exist — and
  `applied` and `screening` differ by shade alone because they are one step
  apart. Nothing more should be inferred: `interviewing`'s indigo is not a
  promise that hue tracks standing.
- **Stale rows are styled, not hidden.** Warning color on the date column, plus
  the sidebar filter. If ghosting hides rows I will forget those companies exist.
  Orange is staleness and nothing else: a chip never restyles because a row went
  quiet, or the one thing warning me is two things.
- **Editing happens in the inspector.** Not inline in the table — inline editing
  in SwiftUI `Table` will eat a weekend.
- **Adding is toolbar `+` → sheet.** Not a blank row appended to the table.
- **Deleting is asked about first.** `⌘⌫` or `File ▸ Delete Application…`, on
  the selected row, behind a confirmation naming the row. Never a bare `⌫` — a
  menu key equivalent is matched before the key reaches the field I am typing
  in, and I am not losing an application to a backspace in the notes field.

`MenuBarExtra` quick-add (company + title, straight to the store, same
`ModelContainer`) is a later milestone, not v1.

### Deleting is the one act that destroys work

There is no undo and no trash. A deleted Application is gone, which is why it
takes a confirmation naming the row to get there. Deleting is not archiving —
an Archived Application is still tracked; a deleted one no longer exists.

**Deleting the last Application at a Company takes that Company with it**, and
so does an import that files it under a different Company. A Company is not
work: it is never managed directly, it exists only because something was applied
for there, and once empty it shows in no view while still being written into
every backup — the file would slowly fill with names I never applied to.

A Company that still holds an Application is never removed. That check is what
keeps the cascade delete rule from taking work with it, and it is unit-tested.

## Backup

The app writes the full dataset as JSON to a user-chosen folder on every save,
debounced ~2s after the last change. Point that folder at Google Drive or iCloud
Drive and it syncs for free.

- Requires a **security-scoped bookmark** persisted from the open panel and
  resolved at launch — a sandboxed app cannot just remember a path.
- **Import is manual only** (`File ▸ Import…`). Never automatic. Auto-import
  means conflict resolution, and two machines writing one file is a distributed
  systems problem this app will not have.
- **This is backup, not sync.** One machine writes; the file is a snapshot. The
  README says so in these words. Claiming "sync" and shipping a one-way mirror
  is the kind of thing an interviewer catches.

### Import merges. It never deletes.

Importing into a store that already holds data:

- Applications match on their stable id. A **known id is updated in place** from
  the file; an **unknown id is inserted**.
- A row in the store that the file does not mention is **left alone**. Import
  never deletes anything.
- Companies resolve through the same case- and whitespace-insensitive
  find-or-create the add sheet uses, so `"spotify"` in a file joins the existing
  `"Spotify"`.
- Re-importing the same file twice therefore changes nothing.

The consequence is deliberate and I accept it: an application I deleted comes
back if I import a file written before I deleted it, and the store can only ever
grow by importing. That is the price of an import that can never lose work, and
losing work is the failure I care about. A row that reappears is an annoyance I
can fix in two clicks; a row destroyed by a mis-click on `Import…` is gone.

This makes import a merge, not a restore. Restoring a machine to an exact
snapshot is not a thing this app does.

Round-trip is unit-tested: export → import → identical dataset.

## Verification

I do not read the code, so tests and screenshots carry the full load.

- **`swift test` in `CandidoCore`** — the only thing between me and an app
  that compiles while computing staleness wrong. Covers: silence-tolerated
  boundaries per status, `lastContactDate` clock, find-or-create case folding,
  JSON round-trip.
- **Agent screenshots itself** — build, launch, capture, attach to the report. I
  review pixels, not diffs. Catches "compiles fine, table renders empty," which
  no unit test will.
- **This document** — agent-written tests test agent-written behavior. If the
  agent misread the spec, code and tests agree and both are wrong. The only
  defense is that the spec is mine and I diff behavior against it, not against
  the implementation.

## Milestones

Slices are chosen to vary the *agent workflow*, not just the feature. The app is
held roughly constant as backdrop.

| # | Workflow under test | Output |
| --- | --- | --- |
| M0 | **One-shot, unattended.** Whole spec, throwaway branch, walk away | Control group. Whatever it gets wrong is what the process must fix |
| M1 | `/grill-me` → spec | This document ✅ |
| M2 | Plan mode + `/to-tickets` | Spec becomes grabbable issues |
| M3 | `/tdd` red-green on the domain package | `CandidoCore`, tested. **App in daily real use from here** |
| M4 | Parallel subagents, independent tracks | Export mirror ‖ `MenuBarExtra` |
| M5 | `/code-review` + `/security-review` | Does the reviewer catch what I can't? |
| M6 | `/loop` or scheduled agent | Background maintenance, dependency bumps |
| M7 | `/writing-great-skills` | Encode whatever motion I kept repeating |

M0 runs **first**, before any structure exists. Without a control group I will
never know whether the ceremony bought anything.

**Known risk:** the app becomes a vehicle I stop caring about, leaving six
half-features and a lot of process. Mitigation is the M3 gate — real
applications tracked in it, or the later experiments have no ground truth.

## Appendix: the name

The product is **Candido**, and as of this amendment the code says so too: the
package is `CandidoCore`, the target and scheme are `Candido`, and the bundle
identifiers are `com.candido.Candido` and `com.candido.Candido.dev`.

This spec previously froze the code on the old name `JobTracker` to protect the
sandbox container: a sandboxed app's container is keyed by its bundle
identifier, so renaming the identifier points the app at a fresh, empty
container and hides every application already tracked. That reasoning was sound
and still is — it simply did not apply yet. The rename landed while the Release
container `com.candido.JobTracker` had never held a store, so there was nothing
to migrate.

That window is now closed. The identifiers above are load-bearing: once real
applications live in the Release container, renaming again requires a container
migration and evidence that nothing was lost. Do not "tidy" them.

`dev.candido.JobTracker` belongs to the frozen M0 control run. Do not touch it.

This appendix is deliberately at the end of the file: `jobtracker-yardstick`
cites this spec by line number, and an amendment inserted above existing text
would move every citation in the checklist. Amend it here, in place.
