# Parallel agent tracks cost more than they returned

M4 tested parallel subagents on independent tracks: a worktree per issue, claimed
by `scripts/worktree.sh`, so two sessions could work the repo at once without
sharing a checkout. It is **closed as a negative result**. The coordination it
demanded exceeded anything it returned for a solo owner, and the machinery is
deleted rather than left in place unused.

The costs were concrete. Every session paid a startup ritual to claim a tree
before it could read anything. `CLAUDE.md` carried a long section whose only job
was stopping two sessions colliding. The script hardcoded an `m2/` branch prefix,
so every branch created after M2 ended was misnamed, and `CONTEXT.md` had to
carry a standing warning not to infer the milestone from a branch name — a
milestone number that decides which score file a run lands in. Against that: the
owner works serially, and nothing had claimed a second worktree in some time.

The isolation was never total, either. Every Debug build uses the bundle
identifier `com.candido.Candido.dev`, and a sandboxed app's container is keyed by
that identifier, so parallel sessions shared one store however separate their
checkouts were. The app could only ever be launched one session at a time.

## Consequences

Work happens in the checkout the session is already in. Branches are
`<issue>-<slug>` with no prefix. `scripts/` is gone; it held nothing else.

The commit discipline survives the machinery, because the incident that produced
it was real. On **22 Jul 2026** two sessions shared a checkout and one committed
its work onto the other's branch, pushing it into their pull request — the tree
it committed to was not the tree it had read `git status` from at startup. The
rules that grew out of that day now stand on reasons that do not need parallel
sessions: stage paths by name because the tree carries untracked local files that
must not ride along, re-read `git status -sb` before committing because a startup
snapshot goes stale on its own, and stop rather than guess when the tree holds
changes you did not make.

Branches already on the remote still carry the wrong `m2/` prefix. Nothing
creates new ones, but the old names remain misleading, which is why `CONTEXT.md`
keeps its warning.

The wrong-but-tempting fix is **re-adding worktree isolation** on the assumption
nobody considered it. It was considered, built, run as a milestone, and measured.
Parallelism is worth revisiting only if the repo gains more than one concurrent
human or agent driver — not to make a single session tidier, which is the reason
it will be proposed.
