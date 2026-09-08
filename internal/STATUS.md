# Where this actually stands

Separating what is proven by a test, what is proven by having run it, and
what is written but has not yet met a real user. A green build says nothing
about the third column.

## Proven by tests — 93 on the Mac, 94 on the iOS Simulator (one live, skipped unless pointed at a repository)

`swift test` runs them on the Mac; `xcodebuild test -scheme Beacon-Package -destination
'platform=iOS Simulator,name=<device>'` runs the same suites on iOS, plus one that only
means anything there.

- The bug gate: the three required fields, the placeholder list
  ("n/a", "it broke", "asdf"), too-short answers, blank step rows, the
  reproducibility warning that must not block.
- The feature gate: an area or "something new" is required; the *why* is
  asked for but never required.
- Issue rendering: fixed headings, verbatim quoting including multi-line,
  numbered steps, the label set, that the app never sets severity, title
  derivation without cutting mid-word, and that the metadata block parses
  as JSON.
- Redaction: six credential shapes, host-declared secrets, that short host
  secrets are ignored, that ordinary prose is untouched, that text
  attachments are swept and binaries aren't, home-directory redaction.
- Consent: per-version and per-person acceptance; that rewording re-asks;
  that the notice names the organisation and says it isn't anonymous.
- The app map: JSON round trip, refusing a newer schema, hidden areas being
  routable but not offered, the sentinels always rendering a name.
- The log ring: capacity, eviction order, tail ordering, level filtering,
  categories, clearing.
- The folder scan: names and sizes recorded, **contents never** (a known
  string is written into a scanned tree and asserted absent), build output
  skipped rather than walked, depth bounded, truncation said out loud, root
  path redacted.
- The archive: report, issue and attachments written; bytes kept out of the
  JSON; awkward filenames flattened.
- Transports: that saving locally never claims to have filed, that the
  fallback takes over and says so, that it reports why, that attachment
  links don't disturb the prose, and that GitHub's status codes turn into
  sentences a reporter can act on.
- Seeding: both switches required, missing folder is safe, every outcome
  explains itself.
- The on-device pass: unavailability is honest rather than silently
  approving, questions override the model's own completeness flag, blank
  questions are dropped, an unknown field name falls back instead of
  crashing.
- Capture, the part that needs no screen: frames come out of a real video
  (written with AVAssetWriter in the test) as PNGs in time order; a picked
  video always travels with its frames; a picked photo loses its location
  and camera metadata; a format nobody downstream can read is turned away;
  the permission and unavailability sentences name the platform they run on.
- The device is named once (`PlatformWording`) and the sentences that name
  it go through that home; on iOS the probe reports the device, not the
  simulator's architecture or the board name.

## Proven by running it

- `beacon-index` run against this package: 8 areas, 25 screens, correct
  paths. It is wired into CI so it indexes itself on every push.
- The whole package builds clean under Swift 6.3 strict concurrency for
  macOS 26 and for the iOS 26 Simulator, with no warnings.
- **The sheet on iOS, walked end to end (2026-09-07)** in
  `Examples/BeaconExample` on the iPhone Air simulator: walkthrough,
  consent, the bug form (menus for the exclusive choices, the growing steps
  list), a screenshot taken from inside the sheet that shows the app and not
  the form, the recording strip collapsing the sheet while the app stays
  usable behind it, a photo picked from the library, review with the full
  issue preview, the on-device check running, and a report saved to the
  app's container with the log tail and `iPhone18,4 (Simulator)` in it.

## Written, but not yet run against reality

These are the ones to be careful about. Nothing here is known to be broken;
none of it has been proven right either.

- **The reporter's flow on screen, on the Mac.** Walked on iOS (above);
  on macOS every view compiles and the same state machine runs, but nobody
  has walked it end to end in a real Mac app. The example app builds for
  macOS too, so that walk is one `xcodegen generate` away.
- **Screen recording, on either platform.** The Mac path is written
  against the ScreenCaptureKit headers in the macOS 26.5 SDK and has not
  yet recorded a real window; the first run will need the Screen Recording
  permission granted by hand. The iOS path (`RPScreenRecorder`) starts,
  collapses the sheet to its strip and stops cleanly in the simulator, but
  the simulator's recorder hands back an empty file — the sheet says so.
  A video, and the frames pulled from it, need a physical iPhone or iPad;
  frame extraction itself is proven by test against a real video.
- **The on-device check against the real model.** The types match Apple's
  shipped interface (`@Generable`, `@Guide(.anyOf:)`, `.maximumCount`,
  `respond(to:generating:)`), and availability is read as state. What the
  model actually *says* about a thin bug report is unknown until it runs.
  The prompt will need tuning; that is normal and the reason questions are
  advisory rather than blocking.
- **Filing to GitHub — now proven (2026-09-07).** `LiveTransportTests`,
  run on purpose against a private repository, created the attachment branch,
  committed a file to it and filed issue #3 with labels and the attachment linked; `swift test`
  without the two variables skips it. The device flow still follows
  GitHub's published endpoints and error codes without having been run
  (no OAuth App is registered). The attachment path — a commit to a
  `beacon-attachments` branch — has a known cosmetic limit: on a private
  repository, images link rather than preview inline, because raw URLs need
  auth.
- **Triage.** The policy and the skill are written. No issue has been
  triaged by them.
- **Cloud reproduction.** The workflow is deliberately shipped failing at
  the run step, so a half-wired setup can't report a green run that proved
  nothing. It needs pointing at a host app's UI test scheme.

## Proven by running it — the inbox route (2026-09-04)

- `Inbox/index.html` is published as a Claude artifact with the `db` and
  `artifact` capabilities; the database is readable from a Claude session
  with the Artifact tool, and a watch on the artifact connects.
- `BeaconInbox.url(...)` builds the link the app opens; four tests hold the
  query keys equal to the ones the page reads.
- **Proven 2026-09-07:** a real send from the page (BN-8EA6C3, by the
  owner, from the Claude desktop app) → filed as issue #1 on the app's repository →
  outcome written back and shown on the board.
- **Still unobserved:** the doorbell publish waking a watching session. The
  send above happened while a watch showed connected and no notice was
  seen. The scheduled pickup covers it either way.

## Decisions still open

- **Which transport — decided 2026-09-07 as two setup paths** (`docs/
  setup-claude-only.md`, `docs/setup-github.md`), each adopter's own
  choice. The reference deployment uses the page for every app, plus the
  direct GitHub transport for the macOS sheet once its owner registers the
  OAuth App (their sign-in; nothing registered yet). No relay is deployed and none is
  planned until someone needs it.
- **The name.** "Beacon" is an authored default and can be swapped; it
  appears in the module names, so changing it later is a rename across the
  package rather than a one-line edit.
- **iOS — built 2026-09-07.** The ReplayKit recording path and the
  view-hierarchy screenshot sit behind the same `ScreenPermission` /
  `ScreenCapturer` / `ScreenRecording` names as the Mac path; the sheet
  collapses to a strip while recording; the Photos picker is offered; the
  device probe reads `hw.machine` (or the simulator's environment); every
  sentence that named "this Mac" now asks `PlatformWording`; the consent
  wording changed ("this device"), so its version moved and everyone is
  asked again. Not yet done: a recording produced on a physical device,
  and the iOS build in CI (a change to the workflow file, which is the
  owner's call).
