import Foundation

/// The rules an edit obeys.
///
/// Three of the editable fields have any: a title has to stay identifiable,
/// the posting URL is typed as text and has to become a link, and a Status
/// change is Contact, so it carries the last-contact date with it. Notes and
/// the last-contact date itself are bound straight to the model — moving that
/// date *is* clearing staleness, so there is nothing extra for it to do.
///
/// `appliedDate` is absent on purpose: it is set once and never changes.
extension Application {
    /// Records a Status change: the Application moves, and its last contact
    /// becomes today.
    ///
    /// A Status change is Contact. Nearly every one of them happens because
    /// they wrote — a rejection, an invitation to screen, an offer — and the
    /// date the owner cares about is the date of that letter, not the date
    /// they last remembered to edit the field. Leaving the two to be
    /// maintained separately is what makes a row that was answered this
    /// morning read as Stale.
    ///
    /// **Except into `withdrawn`.** Withdrawing is the owner's act alone:
    /// nobody wrote to anybody, so nothing about the last contact changed.
    /// The carve-out is on arriving there and not on the Status — leaving
    /// `withdrawn` stamps like any other change, because something brought the
    /// pursuit back and that something came from them. See
    /// `docs/adr/0007-a-status-change-is-contact.md`.
    ///
    /// Re-selecting the Status a row already has is not a change and does
    /// nothing: a `Picker` can fire on re-selection, and the Status control
    /// must not become a covert way to reset the clock.
    ///
    /// The stamp is a default, not a lock. The inspector's date field still
    /// writes `lastContactDate` directly afterwards, which is how a rejection
    /// learned on Thursday is recorded as having arrived on Monday.
    ///
    /// Assigning `status` directly remains legal and does not stamp. That is
    /// deliberate rather than an oversight: `Application.create` and the backup
    /// importer both set a Status while constructing or restoring a record, and
    /// neither is Contact. A restore that stamped would age every row in a
    /// backup to today, which would leave the owner with a backup that is not
    /// one.
    ///
    /// `today` is not defaulted, in keeping with every other date-aware call in
    /// the package: `Today` exists precisely so the day and the calendar it is
    /// read in cannot be left implicit.
    public func changeStatus(to status: Status, asOf today: Today) {
        guard status != self.status else { return }
        self.status = status
        guard status != .withdrawn else { return }
        // The day, not the moment the picker moved: no rule reads a time of
        // day (`docs/adr/0001-calendar-days-for-staleness.md`), so storing one
        // would persist a number nothing consults into every backup.
        lastContactDate = today.startOfDay
    }

    /// Whether this typed title is one worth keeping. The inspector shows its
    /// warning on this, so what the field complains about and what `rename`
    /// refuses are the same rule — and the same rule the add sheet enforces.
    public static func canRename(to title: String) -> Bool {
        isKeepableTitle(title)
    }

    /// Replaces the title, ignoring a blank one.
    ///
    /// A blank title is refused rather than stored: the table would show a row
    /// the owner cannot identify, and there is no undo to get the old title
    /// back from.
    public func rename(to title: String) {
        guard Application.canRename(to: title) else { return }
        self.title = title.trimmed
    }

    /// The posting URL as the inspector edits it — text, because that is what
    /// a pasted link is before it is anything else.
    public var jobURLText: String {
        jobURL?.absoluteString ?? ""
    }

    /// Interprets typed text as the posting URL.
    ///
    /// Text with no scheme is assumed to be `https` — postings are pasted out
    /// of a browser bar as often as copied whole, and a bare host stored as-is
    /// would not open. Text that is not a link at all leaves no URL rather
    /// than storing something unopenable.
    public func setJobURL(fromText text: String) {
        jobURL = Application.jobURL(fromText: text)
    }

    static func jobURL(fromText text: String) -> URL? {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), url.host()?.isEmpty == false else { return nil }
        return url
    }
}
