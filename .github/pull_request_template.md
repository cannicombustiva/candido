<!--
The owner does not read the Swift. An unchecked box is the only signal that a
verification step did not happen, so a step you skipped should be *stated* here
rather than left out. A skipped step declared with its reason is fine; a
skipped step passed off as done is the failure this template exists to prevent.
-->

Closes #

## What changes, in behaviour

<!-- What the app does differently now, not what the diff does. "Applications
go stale one day after the threshold, not on it" — not "added a `>` comparison
in isStale". -->

## Verification

- [ ] `swift test` passes — paste the summary line
- [ ] Behaviour checked against `SPEC.md`, naming the section: <!-- e.g. the silence tolerated per Status, and the strict `>` boundary -->
- [ ] This change touches UI, and a screenshot is attached
- [ ] This change does not touch UI, so no screenshot is needed

### Steps I skipped, and why

<!-- Name every verification step you did not run, and say why. "screencapture
failed with 'could not create image from display' — the terminal lacks Screen
Recording permission" is a complete answer. Leaving this empty means you ran
everything above. -->

## Anything the owner has to do

<!-- Settings that cannot be changed from a PR, tags to push, SPEC.md wording
to apply by hand. Write "nothing" if there is nothing. -->
