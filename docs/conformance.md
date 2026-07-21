# Conformance checklist

Hand-derived from `SPEC.md`. **Written before M0 runs**, deliberately — a
checklist written after seeing the output gets unconsciously graded on what the
output happened to do.

This is the fixed yardstick. Every milestone is scored against this same list,
so results are comparable across workflows. Do not add items to excuse a run,
and do not drop items a run failed. If the spec changes, change this file in the
same commit and note which milestone scores are invalidated.

Each item is checkable **without reading the implementation** — the owner does
not read Swift.

- **Tier D (domain)** — checkable by a fresh agent writing tests against the
  package's public API. Never score using the run's own tests: agent-written
  tests test agent-written behaviour, so they pass and tell you nothing
  (`SPEC.md:155`).
- **Tier U (UI)** — checkable only by launching the app and looking. Slow, needs
  the owner's eyes, catches "compiles fine, table renders empty" — the failure
  no unit test will (`SPEC.md:154`).

Score each: **pass** / **fail** / **n/a (not built)**. "Not built" is not a
pass.

---

## Tier D — domain

### Staleness thresholds (`SPEC.md:90-100`)

The boundary is strict: `> threshold`, not `>=`.

| # | Status | Days since `lastContactDate` | Expected |
| --- | --- | --- | --- |
| D1 | `applied` | 20 | not stale |
| D2 | `applied` | 21 | **not stale** (boundary) |
| D3 | `applied` | 22 | stale |
| D4 | `screening` | 14 | **not stale** (boundary) |
| D5 | `screening` | 15 | stale |
| D6 | `interviewing` | 10 | **not stale** (boundary) |
| D7 | `interviewing` | 11 | stale |
| D8 | `offer` | 200 | not stale — ball is in my court |
| D9 | `rejected` | 200 | not stale — terminal |
| D10 | `withdrawn` | 200 | not stale — terminal |

### Staleness clock (`SPEC.md:102`)

| # | Scenario | Expected |
| --- | --- | --- |
| D11 | `applied` 60 days ago, contacted yesterday | not stale — clock runs from `lastContactDate`, not `appliedDate` |
| D12 | `appliedDate` after creation | unchanged — set once, never changes (`SPEC.md:60`) |

### Staleness is derived (`SPEC.md:78-80`, `SPEC.md:105`)

| # | Scenario | Expected |
| --- | --- | --- |
| D13 | Read `isStale` twice with the clock advanced past the threshold between reads | second read flips to stale with no write, no mutation, no background job |
| D14 | Inspect the model | no stored `isStale` field, no staleness history, no audit log, no event table |

### Company find-or-create (`SPEC.md:48-51`)

| # | Input sequence | Expected |
| --- | --- | --- |
| D15 | `"Spotify"` then `"spotify"` | one Company |
| D16 | `"Spotify"` then `" Spotify "` | one Company |
| D17 | `"Spotify"` then `"SPOTIFY"` | one Company |
| D18 | `"Spotify"` then `"spotify"` | stored display name is `Spotify` — first spelling wins |
| D19 | `"Spotify"` then `"Monzo"` | two Companies |

### Views (`CONTEXT.md`, resolving `SPEC.md:112`)

Derived from `Status`; no stored flag.

| # | Filter | Expected members |
| --- | --- | --- |
| D20 | Active | `applied`, `screening`, `interviewing`, `offer` |
| D21 | Archived | `rejected`, `withdrawn` |
| D22 | Stale | strictly a subset of Active |
| D23 | All | every Application |
| D24 | Model inspection | no `archived` boolean on `Application` |

### JSON backup (`SPEC.md:129-142`)

| # | Scenario | Expected |
| --- | --- | --- |
| D25 | export → import | identical dataset, round-trip |
| D26 | Export contents | the **full** dataset, not a delta |
| D27 | Import trigger | manual only; nothing imports automatically |

### Model shape (`SPEC.md:38-70`)

| # | Expected |
| --- | --- |
| D28 | `Company.name` unique; `Company.applications` one-to-many, inverse of `Application.company` |
| D29 | `Application` carries `company`, `title`, `status`, `appliedDate`, `lastContactDate`, `jobURL` (optional), `notes` |
| D30 | No `salary` field, no `nextActionDate` field, no `source` field — all explicitly rejected or deferred |
| D31 | Both `@Model` types live in `JobTrackerCore`, not the app target |

### Structure (`CLAUDE.md`, `SPEC.md:27`)

| # | Expected |
| --- | --- |
| D32 | Thresholds, date maths, name matching and encoding all live in `JobTrackerCore` — no decision logic in the app target |
| D33 | `swift test` runs and passes |

---

## Tier U — UI

Launch the app and look. Seed enough rows to judge, including at least one
stale and one archived.

| # | Expected |
| --- | --- |
| U1 | Window opens; the table renders **rows**, not an empty view |
| U2 | Single window, `NavigationSplitView` shape — sidebar, content, inspector (`SPEC.md:110`) |
| U3 | Sidebar offers All / Active / Stale / Archived, and each filter changes what the table shows |
| U4 | Table columns sort |
| U5 | Stale rows are **styled, not hidden** — warning colour on the date column, still present in All and Active (`SPEC.md:117`) |
| U6 | Selecting a row opens an `.inspector()` panel showing notes and URL |
| U7 | Editing happens in the inspector — **not** inline in the table (`SPEC.md:120`) |
| U8 | Toolbar `+` opens a **sheet** — not a blank row appended to the table (`SPEC.md:122`) |
| U9 | Typing an unknown company name in the add sheet silently creates it; no "manage companies" screen exists (`SPEC.md:45`) |
| U10 | Choosing a backup folder presents an open panel and survives an app restart — security-scoped bookmark persisted and resolved at launch (`SPEC.md:133`) |
| U11 | `File ▸ Import…` exists and is the only import path |

---

## Out of scope for M0

Not scored. Named here so a run isn't penalised for their absence.

- `MenuBarExtra` quick-add — later milestone (`SPEC.md:124`)
- `source` field — deferred to v2 (`SPEC.md:65`)
