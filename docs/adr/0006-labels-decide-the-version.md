# Labels decide the Version, and MAJOR is a human's

A merged pull request's labels decide what the next Version is: `feat` bumps
MINOR, `fix` and `refactor` bump PATCH, everything else cuts no Release at all.
The number is computed from the labels alone, and no MAJOR bump can be reached
that way — `2.0.0` can only ever be a Tag someone pushed on purpose.

Reading labels runs against every mainstream tool: `semantic-release` and
`release-please` both read commit subjects, and requiring `feat:` prefixes is
what most projects do. The reason not to here is local. This repo's commit
subjects are deliberate prose — *"The chip's colours are a list, not a rule"* —
and `.github/release.yml` already documents that GitHub's note generator can
group only by label, never by title prefix. The repo had therefore already
chosen labels once, for the release notes. Adding conventional-commit prefixes
would have created a second vocabulary carrying the same information, applied by
hand at a different moment, able to disagree with the first — and to disagree
silently, since nothing compares them. One label, applied once per pull request,
decides both the heading and the number.

MAJOR is manual-only because a breaking change is not yet definable for this
app. Candido is local-only with one user, so the surfaces that might one day
justify a `2.0.0` — an existing store or an existing backup becoming unreadable
by a newer build — are known but untested by experience. A rule guessed now
would fire by accident before anyone knew what it meant. When there is something
real to write down, it gets its own ADR.

## Consequences

The label is load-bearing in a way it was not before. Mislabelling a pull
request used to put it under the wrong heading in the notes; it now also decides
whether anything ships and by how much. The failure is biased on purpose:
forgetting a label cuts no Release, so a slip under-claims rather than
over-claiming, and the fix is a Tag pushed by hand rather than a Version that
has to be taken back.

Nothing enforces one label per pull request, so several bumping labels can
arrive together. The largest wins, which is why a `feat` shipped alongside
`docs` is still a `feat`.

Because MAJOR cannot be automated, the changeover to `1.0.0` is itself a
hand-pushed Tag — the last version number a human types here until a breaking
change is defined.
