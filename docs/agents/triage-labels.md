# Labels

Two sets, doing two unrelated jobs. **Triage labels go on issues** and drive the
triage state machine. **Changelog labels go on pull requests** and decide which
heading a merged PR lands under in the generated release notes.

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

| Label      | Heading in the release notes | For                                            |
| ---------- | ---------------------------- | ---------------------------------------------- |
| `feat`     | Features                     | New capability a user can reach                |
| `fix`      | Fixes                        | Wrong behaviour made right                     |
| `docs`     | Documentation and the spec   | Prose, README, ADRs, `CONTEXT.md`, screenshots |
| `spec`     | Documentation and the spec   | Changes to `SPEC.md` — owner-applied only      |
| `refactor` | Refactoring                  | Shape changes with behaviour held still        |
| `test`     | Tests and chores             | Tests added or reworked                        |
| `chore`    | Tests and chores             | Build, CI, licence, repo furniture             |

**Apply exactly one when you open a PR.** Two labels put the same PR under two
headings.
