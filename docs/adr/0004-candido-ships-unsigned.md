# Candido ships unsigned, and says so

There is no paid Apple Developer account and there will not be one. Notarization
requires one, so the app is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`) and cannot
be notarized. macOS quarantines anything a browser downloads, and on macOS 15+
Apple removed the right-click ▸ Open bypass, so **every** first launch requires a
visit to System Settings ▸ Privacy & Security ▸ Open Anyway.

That friction is permanent and cannot be engineered away at this price. The
decision is therefore not whether to have it, but whether to explain it. The
README states it plainly, names the exact dialog, gives the click path, and says
it is once-only — because the alternative is a stranger meeting an unexplained
security warning for software with no signature and no company behind it, and
concluding it is malware.

## Consequences

Anyone who wants to use Candido rather than build it can, at the cost of one trip
through System Settings. Nobody is misled about what they are accepting.

The artifact is a **dmg**, not a zip, and that choice is load-bearing. A
quarantined app launched from `~/Downloads` — or from a mounted disk image — is
run by macOS from a randomised read-only path. This is App Translocation, and its
symptom is unexplained behaviour the user has no way to diagnose. Moving the app
to `/Applications` in Finder *before* first launch is what avoids it. A dmg
containing the app beside an `/Applications` alias makes the drag the whole
interaction, so the step that prevents the worst failure mode is the one the user
cannot skip. A zip would leave `Candido.app` loose in Downloads, where
double-clicking it is both the natural and the wrong next move.

Two alternatives are worth naming, because both look like oversights and neither
is.

**Homebrew is the one genuinely frictionless free path.** A cask strips the
quarantine attribute on install, so `brew install --cask candido` would skip the
Gatekeeper trip entirely, at no cost and with no Developer account. It is
**deferred, not rejected** — it wants a stable release history behind it, and
there are no releases yet. Revisit it once tags exist.

**`create-dmg` with AppleScript window styling** is the obvious upgrade to make
the dmg look designed — a background image, positioned icons. It drives Finder
through AppleScript, which hangs on headless CI runners. The dmg is built with
plain `hdiutil` for that reason, and should stay that way unless someone is
prepared to own a flaky release job.
