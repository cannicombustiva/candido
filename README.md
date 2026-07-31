# Candido

Candido is a macOS app for tracking job applications, and the backdrop for an
experiment in driving coding agents. It keeps one row per application, remembers
when either side last made contact, and surfaces the ones that have gone quiet.

Local-only SwiftData, no account, no server, no paid Apple Developer account.

[![Download for macOS](docs/assets/download-button.svg)](https://github.com/cannicombustiva/candido/releases/latest/download/Candido.dmg)

<!-- SCREENSHOT GOES HERE — see issue #63. The image is captured from the Debug
     build, which has its own sandbox container, so it shows fictional rows
     rather than the owner's real applications. -->

macOS 15 or later, Apple Silicon. It is **unsigned**, so the first launch takes
one trip through System Settings — [see below](#first-launch).

- [`SPEC.md`](SPEC.md) is the contract — hand-written, and the source of truth.
  When the code and the spec disagree, the code is wrong.
- [`CONTEXT.md`](CONTEXT.md) is the glossary for the domain language.
- [`docs/adr/`](docs/adr) records the decisions that were close calls.

## What it does

Applications move through six statuses: `applied`, `screening`, `interviewing`,
`offer`, `rejected`, `withdrawn`. An application is **stale** when the company
owes the next reply and has been silent longer than that status allows:

| Status | Waiting on them | Goes stale after |
| --- | --- | --- |
| `applied` | yes | 21 days |
| `screening` | yes | 14 days |
| `interviewing` | yes | 10 days |
| `offer` | no — your move | never |
| `rejected` / `withdrawn` | no — over | never |

Staleness is computed on every read, never stored, and never mutated by a
background job. The boundary is strict: at exactly 21 days an `applied` row is
not yet stale, at 22 days it is. Days are calendar days in the local timezone,
so rows turn stale at local midnight regardless of the time of day they were
sent.

Stale rows are styled, not hidden — the sidebar filters to them, but they stay
visible in the other views too.

## Backup, not sync

The app mirrors the whole dataset to a JSON file in a folder you choose. Point
that folder at Google Drive or iCloud Drive and it gets carried off the machine
for free. (Not shipped yet — the design below is what `SPEC.md` commits to, and
this section describes the behaviour the mirror will have.)

**This is backup, not sync.** One machine writes; the file is a snapshot. There
is no merge on write, no conflict resolution, and no second machine writing the
same file. Import is manual only (`File ▸ Import…`) and never automatic, and
importing merges — a known application id is updated in place, an unknown one is
inserted, and a row the file does not mention is left alone. Import never
deletes.

## Layout

```
Package.swift              CandidoCore package manifest
Sources/CandidoCore/       Domain: models, staleness, find-or-create, JSON codec
Tests/CandidoCoreTests/    swift-testing tests for the above
App/                       SwiftUI app target sources + entitlements
project.yml                xcodegen spec — source of truth for the app target
```

Everything with a decision in it — thresholds, date maths, name matching,
encoding — lives in the `CandidoCore` package, so `swift test` reaches it in
seconds without a GUI run. The app target holds views and wiring only.

## First launch

Candido is ad-hoc signed. There is no paid Apple Developer account behind it and
there will not be one, so it cannot be notarized, and macOS will warn you the
first time you open it. The warning is about the *absence of a signature*, not
about anything the app does. It is a once-only step.

**Do these in order.** The order is what matters:

1. **Open `Candido.dmg` and drag `Candido.app` onto the `Applications` alias
   beside it.** Do not launch it from the disk image. A quarantined app run from
   a mounted image — or from `~/Downloads` — is executed by macOS from a
   randomised read-only path, and behaves strangely in ways you cannot diagnose.
   Dragging it to `/Applications` first is what avoids that.
2. **Launch it from `/Applications`.** macOS refuses, saying it cannot verify the
   developer.
3. **Open System Settings ▸ Privacy & Security**, scroll to the Security section,
   and click **Open Anyway** next to the message about Candido. Confirm.

macOS remembers. Every launch after this one is an ordinary double-click.

`docs/adr/0004-candido-ships-unsigned.md` records why this is permanent, and why
the download is a disk image rather than a zip.

## Requirements

### To run

macOS 15 or later, on Apple Silicon.

macOS 15 is the deployment target declared in both `Package.swift` and
`project.yml`. Nothing has been tested on macOS 15 — the floor is stated as
declared, not as verified. Builds are arm64 only; macOS 26 is Apple's last Intel
release and there are no known Intel users.

### To build

Swift 6.3, Xcode 26.6, macOS 26 (arm64), and
[`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

These are the *build* toolchain, not what the app needs in order to run.

## Tests

```bash
swift test
```

This runs the package suite and needs no Xcode project.

## Build and run

`Candido.xcodeproj` is **generated by `xcodegen` from `project.yml` and is not
checked in.** Generate it first, and never hand-edit it or a `.pbxproj` — change
`project.yml` and regenerate.

```bash
xcodegen generate
xcodebuild -project Candido.xcodeproj -scheme Candido \
  -configuration Debug -derivedDataPath DerivedData build
open DerivedData/Build/Products/Debug/Candido.app
```

`xcodebuild` is extremely verbose; `| grep -E "error:|BUILD"` is usually enough.

The Debug build uses its own bundle identifier, `com.candido.Candido.dev`.
A sandboxed app's container is keyed by that identifier, so a Debug build gets
its own store and cannot open — or migrate — whatever a Release build is
tracking. Neither identifier may be renamed; `SPEC.md` says why.
