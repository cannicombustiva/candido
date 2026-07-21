# Job Application Tracker

macOS SwiftUI app for tracking job applications. Local-only SwiftData.

## Read SPEC.md first

`SPEC.md` is the contract and is hand-written by the owner. It defines the
domain model, the staleness rules, the UI shape, and the backup behaviour.

**When code and SPEC.md disagree, the code is wrong.** Do not "fix" the spec to
match an implementation. If the spec is genuinely ambiguous or wrong, say so and
ask — do not silently pick an interpretation.

## Who reviews this code

The owner is a frontend developer and does **not read the Swift**. Nobody is
checking your diff line by line. That means:

- Tests are not a formality. They are the only thing standing between a wrong
  implementation and a wrong app that looks fine.
- Explain behaviour, not code, when reporting. "Applications go stale one day
  after the threshold, not on it" — not "added a `>` comparison in `isStale`."
- If you are unsure whether something matches the spec, flag it. It will not be
  caught downstream.

## Layout

```
Package.swift              JobTrackerCore package manifest
Sources/JobTrackerCore/    Domain: models, staleness, find-or-create, JSON codec
Tests/JobTrackerCoreTests/ swift-testing tests for the above
App/                       SwiftUI app target sources + entitlements
project.yml                xcodegen spec — source of truth for the app target
SPEC.md                    The contract
```

`JobTracker.xcodeproj` is **generated and gitignored**. Never edit it, and never
hand-edit a `.pbxproj`. To change build settings, targets, or add source
directories, edit `project.yml` and re-run `xcodegen generate`.

The app is sandboxed with `user-selected.read-write` and `bookmarks.app-scope`
entitlements — the set the JSON backup mirror in `SPEC.md` needs.

## Rule: logic goes in the package, not the views

Anything with a decision in it — thresholds, date maths, name matching,
encoding — belongs in `JobTrackerCore` where `swift test` can reach it. The app
target holds views and wiring only. This split exists so the feedback loop is
`swift test` (seconds, clean output) rather than a GUI test run.

## Verification

Before reporting work as done:

1. `swift test` passes.
2. If the change touches UI, build and launch the app, screenshot it, and
   include the screenshot. "It compiles" is not evidence the table renders.
3. Check the behaviour against the tables in `SPEC.md` — specifically the
   per-status thresholds and the strict `>` boundary.

Report failures plainly, with output. A skipped step must be named as skipped.

### Build, launch, screenshot

```bash
xcodegen generate
xcodebuild -project JobTracker.xcodeproj -scheme JobTracker \
  -configuration Debug -derivedDataPath DerivedData build
open DerivedData/Build/Products/Debug/JobTracker.app
screencapture -x -T 3 shot.png
osascript -e 'tell application "JobTracker" to quit'
```

The Debug build has its own bundle identifier, `com.candido.JobTracker.dev`,
and therefore its own sandbox container. The owner runs a Release build with
their real applications in it; an agent run must never open that store. Do not
"fix" the identifiers to match. Activate the app before capturing
(`osascript -e 'tell application id "com.candido.JobTracker.dev" to activate'`)
— `screencapture` only sees the active Space, so a fullscreen terminal hides
the app window.

`screencapture` fails with `could not create image from display` unless the
terminal running it has **Screen Recording** permission (System Settings ▸
Privacy & Security ▸ Screen Recording). If it fails, say so and report the step
as skipped — do not claim the UI was visually verified.

Filter `xcodebuild` output; it is extremely verbose. `grep -E "error:|BUILD"` is
usually enough.

## The milestone experiment lives outside this repo

`SPEC.md` describes milestones M0–M7, each testing a different agent workflow.
Two things they need are deliberately **not** in this repo:

- **`../jobtracker-yardstick`** — the conformance checklist and the scoring
  rig. Kept separate so it cannot be edited by the runs it grades. `score/` is
  a Swift package that grades any milestone through a symlink:
  `cd score && ln -sfn ../../candido-m0 subject && swift test`, plus
  `score/tier-a.sh` for artifact checks. Scores land in `scores/<milestone>.md`.
- **`../candido-m0`** — the M0 control run: seeded with `SPEC.md` and nothing
  else, no CLAUDE.md, no CONTEXT.md, no ADRs. **Never edit its `SPEC.md`**, even
  to fix a typo. It is a frozen seed and the comparison depends on it.

If you are amending `SPEC.md`, the checklist and the affected score files must
be updated in step — see that repo's README for the drift rules.

## Agent skills

### Issue tracker

Issues live as GitHub issues on `cannicombustiva/candido`, managed with the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical label names, unchanged (`needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Toolchain

Swift 6.3, Xcode 26.6, macOS 26 (arm64). Tests use `swift-testing`
(`import Testing`, `@Test`, `#expect`), not XCTest.
