# Labels

Two sets, doing two unrelated jobs. **Triage labels go on issues** and drive the
triage state machine. **Changelog labels go on pull requests** and decide which
heading a merged PR lands under in the generated release notes — and, since
these labels also decide the Version, whether there is a release at all.

A label from one set never substitutes for one from the other.

## Triage labels (on issues)

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## Changelog labels (on pull requests)

`.github/release.yml` generates the release notes, and GitHub groups them by
pull request **label**. There is no title-prefix matching — the commit subjects
in this repo already read `docs:`, `fix:` and so on, but the release notes
cannot see them. **An unlabelled PR is not an error; it lands under "Everything
else".**

| Label        | Heading in the release notes | Version    | For                                            |
| ------------ | ---------------------------- | ---------- | ---------------------------------------------- |
| `feat`       | Features                     | MINOR      | New capability a user can reach                |
| `fix`        | Fixes                        | PATCH      | Wrong behaviour made right                     |
| `docs`       | Documentation and the spec   | no release | Prose, README, ADRs, `CONTEXT.md`, screenshots |
| `spec`       | Documentation and the spec   | no release | Changes to `SPEC.md` — owner-applied only      |
| `refactor`   | Refactoring                  | PATCH      | Shape changes with behaviour held still        |
| `test`       | Tests and chores             | no release | Tests added or reworked                        |
| `chore`      | Tests and chores             | no release | Build, CI, licence, repo furniture             |
| `no-release` | Everything else              | no release | Holding a merge back from shipping — see below |

**Apply exactly one when you open a PR.** Two labels put the same PR under two
headings.

## Applying one of these now ships something

Merging a labelled PR mints the Tag and publishes the Release by itself. A
`feat` merged at four o'clock is downloadable at ten past, with nobody deciding
anything. So the label is no longer only a heading — it is the difference
between shipping and not, and by how much.

The rules, in full:

- The largest bump wins when a PR carries several. `feat` alongside `docs` is
  still a `feat`.
- An unlabelled PR cuts no Release. Forgetting under-claims rather than
  over-claims, deliberately.
- MAJOR has no label and cannot be reached. `2.0.0` is a Tag pushed by hand.
- `no-release` suppresses the Release for one PR whatever else it wears. It is
  for holding a half-finished `feat` back without renaming its label and lying
  to the release notes about what the PR was.

Why labels rather than commit prefixes, and why MAJOR stays manual:
`docs/adr/0006-labels-decide-the-version.md`.
