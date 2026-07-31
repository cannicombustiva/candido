# Candido

macOS SwiftUI app for tracking job applications. Local-only SwiftData.

Everything is called **Candido**: the package is `CandidoCore`, the target and
scheme are `Candido`, the bundle identifiers are `com.candido.Candido` and
`com.candido.Candido.dev`. Do not rename the identifiers — the sandbox container
is keyed by the bundle identifier, so changing one hides the owner's real
applications behind a fresh empty store. This rename was safe only because it
happened while the Release container had never held a store; the next one would
need a migration. See "Appendix: the name" in `SPEC.md`.

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

## Rule: commit deliberately

Work on a branch named `<issue>-<slug>` — the issue number, then a short slug,
with no prefix of any kind: `14-day-boundary`, never `m2/14-day-boundary`.

Three rules about committing, each with a reason that stands on its own:

- **Never `git add -A` or `git commit -a`.** Stage the paths you edited by
  name. The tree carries untracked local files —
  `.claude/settings.local.json`, `DerivedData/`, scratch output — and a
  wildcard stage sweeps them into your commit.
- **Re-read `git status -sb` immediately before every commit.** The git
  snapshot in your startup prompt is from startup. A session can be long, and
  branches move under it.
- **If `git status` shows changes you did not make, stop and ask.** Do not
  commit around them and do not revert them. They are someone's work in
  progress, and neither guessing is yours to make.

The settings that enforce this server-side, and the reasoning for each, are in
`docs/branch-protection.md`. They are applied by hand by the owner — an agent
does not change repo settings.

Every Debug build uses the bundle identifier `com.candido.Candido.dev`, and a
sandboxed app's container is keyed by that identifier. All Debug builds
therefore read and write one store — launch the app from one session at a time.

## Layout

```
Package.swift              CandidoCore package manifest
Sources/CandidoCore/       Domain: models, staleness, find-or-create, JSON codec
Tests/CandidoCoreTests/    swift-testing tests for the above
App/                       SwiftUI app target sources + entitlements
project.yml                xcodegen spec — source of truth for the app target
SPEC.md                    The contract
```

`Candido.xcodeproj` is **generated and gitignored**. Never edit it, and never
hand-edit a `.pbxproj`. To change build settings, targets, or add source
directories, edit `project.yml` and re-run `xcodegen generate`.

The app is sandboxed with `user-selected.read-write` and `bookmarks.app-scope`
entitlements — the set the JSON backup mirror in `SPEC.md` needs.

## Rule: logic goes in the package, not the views

Anything with a decision in it — thresholds, date maths, name matching,
encoding — belongs in `CandidoCore` where `swift test` can reach it. The app
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
xcodebuild -project Candido.xcodeproj -scheme Candido \
  -configuration Debug -derivedDataPath DerivedData build
open DerivedData/Build/Products/Debug/Candido.app
screencapture -x -T 3 shot.png
osascript -e 'tell application "Candido" to quit'
```

The Debug build has its own bundle identifier, `com.candido.Candido.dev`,
and therefore its own sandbox container. The Release container is where the
owner's real applications go once the app is in daily use from M3; an agent run
must never open that store. Keep the Debug/Release split. Activate the app
before capturing
(`osascript -e 'tell application id "com.candido.Candido.dev" to activate'`)
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
  `cd score && rm -rf .build Package.resolved && ln -sfn ../../<run> subject &&
  swift test`, plus `score/tier-a.sh <subject>` for artifact checks. Scores land
  in `scores/<milestone>.md`. Runs that predate the rename to `CandidoCore` —
  M0 among them — need `YARDSTICK_PRODUCT=JobTrackerCore` set.
- **`../candido-m0`** — the M0 control run: seeded with `SPEC.md` and nothing
  else, no CLAUDE.md, no CONTEXT.md, no ADRs. **Never edit its `SPEC.md`**, even
  to fix a typo, and never branch or commit there. It is a frozen seed and the
  comparison depends on it staying exactly as it was.

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
