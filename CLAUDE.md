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
SPEC.md                    The contract
```

The app target (Xcode project, SwiftUI views, entitlements) does not exist yet.
`xcodegen` and `tuist` are **not** installed — creating it means either an
Xcode-generated project or adding a generator as a dependency. Raise this rather
than hand-writing a `.pbxproj`.

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

## Toolchain

Swift 6.3, Xcode 26.6, macOS 26 (arm64). Tests use `swift-testing`
(`import Testing`, `@Test`, `#expect`), not XCTest.
