import Foundation

/// The rules an edit obeys.
///
/// Only two of the editable fields have any: a title has to stay identifiable,
/// and the posting URL is typed as text and has to become a link. Status,
/// notes and the last-contact date are bound straight to the model — changing
/// Status *is* archiving, and moving the last-contact date *is* clearing
/// staleness, so there is nothing extra for either to do.
///
/// `appliedDate` is absent on purpose: it is set once and never changes.
extension Application {
    /// Whether this typed title is one worth keeping. The inspector shows its
    /// warning on this, so what the field complains about and what `rename`
    /// refuses are the same rule.
    public static func canRename(to title: String) -> Bool {
        !title.trimmed.isEmpty
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
        guard let url = URL(string: candidate), let host = url.host(), host.contains(".") else {
            return nil
        }
        return url
    }
}
