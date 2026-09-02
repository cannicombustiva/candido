# A Status change is Contact

Last contact is the day every attention rule counts from: Days of silence is
measured to it, and Stale is that count against what the Status tolerates. It
was also, until now, the one field the owner had to maintain by hand.

The moment that most reliably resets it is a Status change. A rejection arrives,
a screen is booked, an offer lands — the owner moves the chip, and the row is now
correct about where it stands and wrong about when it last heard anything. The
stale date sits there ageing until the row warns about silence from a
conversation that happened this morning. Two fields describing one event, one of
which maintains itself and one of which does not, is a trap sprung by using the
app correctly.

So a Status change writes Today into Last contact. **Except into `withdrawn`.**
Withdrawing is the owner's act alone: nobody wrote to anybody, so nothing about
the last contact changed, and stamping it would record a letter that was never
sent.

The carve-out is on *arriving* at `withdrawn`, not on the Status. Leaving it
stamps like any other change, because something brought the pursuit back and
that something came from them — and a row revived after six months that kept its
six-month-old date would read as Stale the instant it was revived, which is
precisely backwards.

The alternative considered was to stamp only Statuses that Await their reply, on
the reasoning that only those have a silence clock for the stamp to affect.
Stamping `rejected` changes nothing anyone can see: an Application that stands
Over can never be Stale. It is rejected because Last contact is not only an input
to staleness. It is a sortable column and a field in every backup, so a date
that is wrong but invisible is still wrong — and for `rejected` the stamp is
simply true, since their rejection *was* the last contact.

That has a visible consequence, and it is intended rather than tolerated: the
Archived view, sorted by Last contact, lists rows in the order the owner
processed them. For a dead row that is the better answer. The question a person
asks of an archived Application is when they last heard, not when they first
wrote.

**Assigning a Status is not changing one.** This is the load-bearing half of the
decision, and the reason the rule is one named act in `CandidoCore` rather than
a `didSet` on the field. `Application.create` and the backup importer both set a
Status while constructing or restoring a record, and neither is Contact. A model
that stamped on every write would need each of them to opt out, and the call
site that forgot would age every row in a restored backup to today — which would
leave the owner holding a backup that is not one, discovered only after they
needed it. Plain assignment therefore stays legal and stays silent; only
`changeStatus(to:asOf:)` stamps.

Re-selecting the Status a row already has does nothing. A `Picker` can fire on
re-selection, and re-affirming `interviewing` after a second interview is real
contact — but saying so through the Status control would make it a covert reset
button next to a date field that already does the job honestly.

The stamp is a default, not a lock. The date field sits directly under the
Status picker and still writes Last contact afterwards, which is how a rejection
learned on Thursday is recorded as having arrived on Monday. Without that, the
rule would make the date *less* accurate than typing it by hand — the owner
back-fills more often than they file in real time.

The day comes from the window's one `DayClock`, the same `Today` the table
styles staleness against, and it is stored as the start of that day. No rule
reads a time of day — `docs/adr/0001-calendar-days-for-staleness.md` settled
that staleness counts calendar days — so keeping one would persist a number
nothing consults into every backup.
