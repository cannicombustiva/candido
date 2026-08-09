# A rename onto a taken name merges

A Company's identity is its folded name, and that is unique, so two Companies
cannot hold one name. Renaming `"Spotfy"` to `"Spotify"` when `"Spotify"`
already exists therefore has to do something, and it **merges**: the
Applications change hands, the emptied Company is cleared away, and the owner is
asked first, in words naming both Companies and the count.

The obvious alternative is to refuse — report the clash and leave the typo
alone. It is rejected because it fails in the only case that matters. A typo is
usually noticed *because* the name was typed correctly the second time, so by
the time the owner goes looking for Rename, the good spelling is already in the
store and the clash is the normal case, not the edge one. A rename that works
solely when nothing collides is a rename that never works.

## Consequences

Merging is not reversible, and no amount of confirmation makes it so: once two
Companies are one, nothing records that they were ever two, and renaming back
produces an empty Company, not the old split. This is the second act in the app
that cannot be undone, and like the first — Delete — the whole protection is
being asked beforehand in words naming the actual rows.

It is nonetheless the *safe* of the two irreversible acts, and deliberately so.
Delete destroys work. Merge only moves it: no Application is deleted by a merge,
the count before equals the count after, and what disappears is a Company, which
is not work — it exists only because something was applied for there. The
existing cleared-away rule does that part, unchanged, and it refuses to remove a
Company still holding anything.

Which makes the ordering load-bearing rather than incidental.
`Company.applications` cascades on delete, so a merge that removed the source
Company before reassigning its Applications would delete the very work it was
moving. Applications change hands first; the source is offered to
`clearAwayIfEmpty` after, never to a bare `context.delete`.

Import stays unaware that any of this happened. A backup written before a merge
still names the Company that no longer exists, and importing it brings that
Company back with the Applications the file files under it. That follows from
import merging rather than restoring, and it is the same price already accepted
for deletes: the store can only grow, and a row that reappears is an annoyance
rather than a loss. Teaching import about renames would mean putting Company
identities in the backup file, which is a format change bought for a rare case.
