# Job Application Tracker — Spec

A macOS app for tracking my own job applications.

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
| Structure | `JobTrackerCore` Swift package + thin app target | `swift test` runs in seconds with clean output — the agent feedback loop |
| Backup | One-way JSON mirror to a user-chosen folder | Point it at Google Drive; no OAuth, no SDK, no paid account |

No paid Apple Developer account. Consequences: no CloudKit sync, no
notarized distribution, repo is the deliverable. `@Attribute(.unique)` is
available (CloudKit would have forbidden it).

## Domain model

Two `@Model` types, both in `JobTrackerCore`.

### Company

| Field | Type | Notes |
| --- | --- | --- |
| `name` | `String` | Unique |
| `applications` | `[Application]` | One-to-many, inverse of `Application.company` |

Companies are never managed directly by the user. There is no "manage companies"
screen. Typing a new name in the add sheet silently creates one.

**Find-or-create is case- and whitespace-insensitive.** `"spotify"`,
`"Spotify"`, and `" Spotify "` all resolve to the same `Company`. The unique
constraint alone does not do this — it is logic in the package, and it is
unit-tested. First spelling entered wins as the stored display name.

### Application

| Field | Type | Notes |
| --- | --- | --- |
| `company` | `Company` | Relationship |
| `title` | `String` | Free text. Not normalized — titles are too messy to be worth an entity |
| `status` | `Status` | See below |
| `appliedDate` | `Date` | Set once, never changes |
| `lastContactDate` | `Date` | Resets whenever either side makes contact. Drives staleness |
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

### Staleness is derived, never stored

There is no background job. Nothing mutates status behind my back. `isStale` is
computed on read, every time.

```
isStale = status.awaitsTheirReply && daysSince(lastContactDate) > threshold(status)
```

**Thresholds are per-status.** Silence after a final interview is louder than
silence after applying.

| Status | Awaits their reply | Threshold |
| --- | --- | --- |
| `applied` | yes | 21 days |
| `screening` | yes | 14 days |
| `interviewing` | yes | 10 days |
| `offer` | no | — (ball is in my court) |
| `rejected` | no | — (terminal) |
| `withdrawn` | no | — (terminal) |

**Boundary is strict.** `> threshold`, not `>=`. At exactly 21 days an `applied`
row is *not* stale. At 22 days it is.

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

- **Stale rows are styled, not hidden.** Warning color on the date column, plus
  the sidebar filter. If ghosting hides rows I will forget those companies exist.
- **Editing happens in the inspector.** Not inline in the table — inline editing
  in SwiftUI `Table` will eat a weekend.
- **Adding is toolbar `+` → sheet.** Not a blank row appended to the table.

`MenuBarExtra` quick-add (company + title, straight to the store, same
`ModelContainer`) is a later milestone, not v1.

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

Round-trip is unit-tested: export → import → identical dataset.

## Verification

I do not read the code, so tests and screenshots carry the full load.

- **`swift test` in `JobTrackerCore`** — the only thing between me and an app
  that compiles while computing staleness wrong. Covers: threshold boundaries
  per status, `lastContactDate` clock, find-or-create case folding, JSON
  round-trip.
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
| M3 | `/tdd` red-green on the domain package | `JobTrackerCore`, tested. **App in daily real use from here** |
| M4 | Parallel subagents, independent tracks | Export mirror ‖ `MenuBarExtra` |
| M5 | `/code-review` + `/security-review` | Does the reviewer catch what I can't? |
| M6 | `/loop` or scheduled agent | Background maintenance, dependency bumps |
| M7 | `/writing-great-skills` | Encode whatever motion I kept repeating |

M0 runs **first**, before any structure exists. Without a control group I will
never know whether the ceremony bought anything.

**Known risk:** the app becomes a vehicle I stop caring about, leaving six
half-features and a lot of process. Mitigation is the M3 gate — real
applications tracked in it, or the later experiments have no ground truth.
