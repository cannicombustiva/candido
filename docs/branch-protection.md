# Branch protection on `main`

These are the settings to apply by hand, and the reasoning for each. Branch
protection cannot be configured from a pull request, so this file is the
deliverable — applying it is the owner's job.

Nothing here was enforceable until CI had passed once. It has: `.github/workflows/ci.yml`
is green on `main`, so there is a real check to require. Turning protection on
before that would have blocked every merge on a check that had never reported.

## The settings

Settings ▸ Branches ▸ Add branch ruleset, targeting `main`.

| Setting | Value |
| --- | --- |
| Require a pull request before merging | On, **0** required approvals |
| Require status checks to pass | On — **`Test and build`** |
| Require branches to be up to date before merging | On |
| Include administrators / bypass list | On / empty |
| Allow force pushes | Off |
| Allow deletions | Off |

## Why each one

**A pull request, but zero approvals.** One person maintains this repo. Requiring
an approval nobody else can give would lock the only account out of its own
`main`, and the workaround — an admin bypass used on every merge — is protection
that exists on paper only.

**`Test and build`, not `CI`.** GitHub matches required checks on the *job* name.
`CI` is the workflow's name and will silently never match, leaving a required
check permanently pending and every PR unmergeable. The job is named on line 20
of `ci.yml`; if that name changes, this setting must change with it, and the
symptom of forgetting is a repo that cannot merge anything.

The check also has to actually report on pull requests, or the same deadlock
follows. `ci.yml` triggers on `pull_request` as well as pushes to `main`, so it
does.

**Up to date before merging.** The full run is about two minutes, which is a
cheap price for the failure it prevents: a PR that passed against an older `main`
and breaks against the current one. This repo has already been bitten by the
neighbouring version of that problem — squash-merging a stack strands the child's
history and the child then conflicts.

**Administrators included.** Excluding them makes every rule above advisory for
the only account that can break them, which is the account that matters. It can
be switched off deliberately in an emergency; the point is that doing so is a
decision rather than the default.

**No force pushes, no deletions.** `main` is what the release tags are cut from.

## What this does not cover

Branch protection applies to branches. It does not apply to tags, and
`release.yml` fires on `v*` tag pushes and publishes a GitHub release using
`github.token`. Nothing above constrains that path. Protecting tags is a separate
tag ruleset and a separate decision — it is deliberately not part of this.
