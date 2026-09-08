# Beacon — Internal Developer Guide

*Last updated: 2026-09-07*

**Audience: people working on Beacon itself** — the Swift package, the page, the pickup,
the triage policy. It is the technical reference: every module, every public type that
matters, the report's shape, the page's storage schema, every call the pickup makes, the
GitHub calls the native transport makes, the CLI, the workflows, the tests, and how to
operate the live page. It describes what the code does today (commit of 7 September 2026).

If you are a founder or a developer **adding Beacon to an app**, you want the public
documentation instead: [docs/](../docs/README.md). Plain words, nothing a maintainer needs.

The other files in this folder: [ADOPTING.md](ADOPTING.md) is the long-form walkthrough of
the native sheet's configuration; [STATUS.md](STATUS.md) separates what is proven by tests
from what is only written; [PRIVACY.md](PRIVACY.md) points every privacy claim at the code
that makes it true; [CLOUD-REPRODUCTION.md](CLOUD-REPRODUCTION.md) is the macOS-runner plan;
[FOR-TESTERS.md](FOR-TESTERS.md) is the native sheet's tester page (the page route's is
`docs/for-testers.md`).

---

## 1. What it is

Two routes into one queue, one policy that works the queue, and two setup paths that
give all of it to someone else without touching any of the owner's accounts (`docs/
setup-claude-only.md`, `docs/setup-github.md`).

- **The page route.** `Inbox/index.html`, published as a Claude artifact with the `db`
  and `artifact` runtime capabilities. The app opens it with the machine's half of a report
  in the query string; the tester writes the rest; the page stores the report in the
  artifact's database and publishes a doorbell file; a Claude session or scheduled task
  reads the database and files the report as a GitHub issue (or works it in place).
- **The native route.** The SwiftUI sheet in `BeaconUI`, which collects diagnostics,
  captures the screen, runs the on-device completeness check, sweeps for secrets, and hands
  a rendered issue to a `ReportTransport` — GitHub direct, a relay, or a local bundle.
- **The policy.** `Triage/TRIAGE.md`, run by the `beacon-triage` skill against GitHub
  issues, and by the scheduled task `beacon-inbox-triage` against both the page and GitHub.

Names: the package was **Flare** until 2026-09-04, and report references changed prefix
from `FL-` to `BN-` at the rename. The repository was published from a fresh history on
2026-09-07; the private history it grew from is archived separately and is not on `main`.

---

## 2. Layout

| Path | What it is |
|---|---|
| `Package.swift` | Swift 6.2 tools, platforms macOS 26 and iOS 26, strict concurrency. Products: `Beacon` (library), `BeaconCore` (library), `beacon-index` (executable) |
| `Sources/BeaconCore` | Values, rules, rendering, the transport seam, the app map, the inbox link, and `PlatformWording` (the one home for "this Mac" / "this device"). **No UI, no platform APIs.** Everything else imports this |
| `Sources/BeaconDiagnostics` | `BeaconLog` (the ring buffer), `EnvironmentProbe`, `FileTreeScanner`, `ContextCollector`, `ReportArchive` |
| `Sources/BeaconIntelligence` | The on-device completeness check on Apple's Foundation Models; `NoReviewer` where it can't run |
| `Sources/BeaconCapture` | Screenshots and recording of the app itself. `Capture.swift` is shared (errors, PNG encoding, frames out of a video, picked photos); `MacCapture.swift` is ScreenCaptureKit, `IOSCapture.swift` is ReplayKit plus the view hierarchy; both present `ScreenPermission`, `ScreenCapturer`, `ScreenRecording` |
| `Sources/BeaconGitHub` | `GitHubClient`, `GitHubDeviceFlow`, `GitHubTokenStore`, and the four transports |
| `Sources/BeaconUI` | `BeaconSheet`, `FormSteps`, `FeedbackSession` (the state machine), `BeaconWalkthrough` |
| `Sources/Beacon` | The façade a host imports: `Beacon.configure`, the view modifiers, `BeaconReportButton`, `BeaconInboxButton`. It re-exports `BeaconCore`, `BeaconDiagnostics` and `BeaconGitHub`, so `import Beacon` is the only import the configuration call needs |
| `Sources/beacon-index` | The indexer CLI |
| `Examples/BeaconExample` | The smallest host app, for iPhone, iPad and Mac: `project.yml` for xcodegen (the `.xcodeproj` is generated and ignored) and one Swift file. Reports go to `LocalBundleTransport`; the saved folder is in the app's container |
| `Inbox/index.html` | The page. The one home; the live artifact is published from it |
| `Inbox/README.md` | The page's own notes: views, storage, the doorbell, the constraint |
| `Triage/TRIAGE.md` | The policy |
| `Triage/PICKUP.md` | The pickup prompt template — account-free; four values to fill in. An owner's own filled-in instance lives outside this repository, as a scheduled task |
| `.claude/skills/beacon-triage/SKILL.md` | The skill that runs the policy against GitHub issues |
| `.claude/skills/beacon-setup/SKILL.md` | The skill that walks an adopter through one of the two setup paths, from `docs/` |
| `.claude-plugin/` | `plugin.json` (the plugin is the repository root; `skills` points at `.claude/skills`, so the skills have one home) and `marketplace.json` (the `up-coast` marketplace with this one plugin, pinned to the release tag). Bump both versions and the tag together on a release |
| `.github/workflows/` | `ci.yml` (build, test, self-index), `beacon-triage.yml` and `beacon-reproduce.yml` (to copy into an app's repo) |
| `.github/ISSUE_TEMPLATE/` | Bug and feature forms for people filing by hand, matching the rendered layout |
| `Scripts/beacon-labels.sh` | Creates the label vocabulary on a repository |
| `Scripts/beacon-adopt-github.sh` | Copies the policy, the pickup template, the skill, the workflows and the issue templates into an app's repository and runs the labels script. The GitHub path's one command |
| `Tests/` | 93 tests in five targets (94 on iOS), one live and skipped by default; see §11 |

Layering rule, enforced by the package graph: each target imports only the ones above it in
the table. `BeaconUI` is the only target that imports the four in the middle.

---

## 3. The report

`FeedbackReport` (`BeaconCore/Report.swift`) is the one envelope every stage works on.

```
FeedbackReport
  id: UUID                      reference = "BN-" + first 6 of id, uppercased
  startedAt: Date               when the sheet opened, not when they hit send
  reporter: Reporter            accountID (required), displayName?, contact?
  title: String                 blank → derived from the first sentence, cut on a word at 72
  body: ReportBody              .bug(BugBody) | .feature(FeatureBody) | .feedback(FeedbackBody)
  impact: Impact                blocked | slowed | irritating | noticed   (rank 0..3)
  areaID: String?               from BeaconIndex; sentinels "unsure" and "new"
  attachments: [Attachment]
  context: ReportContext        app, environment, settings, fileTrees, log, hostNotes
  consentVersion: String        the ConsentNotice version they accepted
  review: CompletenessReview?   what the on-device pass said, or that it couldn't run

BugBody       whatHappened, expected, steps [String], reproducibility (every-time | sometimes | once | unknown)
FeatureBody   whatIWant, why, areaID?, isNewArea
FeedbackBody  message, areaID?
```

`CompletenessRules` (`Completeness.swift`) is the deterministic gate: the three bug fields
required, `minimumMeaningfulCharacters = 12`, the placeholder set ("n/a", "it broke", …)
matched whole after trimming punctuation. Blocking issues stop a send; the reproducibility
nudge is non-blocking. The page carries a verbatim copy of these rules in JavaScript —
**change them here first, then in `Inbox/index.html`**, and keep the messages identical.

`IssueRenderer` (`IssueRendering.swift`) turns a report into `IssueDraft {title, body,
labels}`. Fixed headings: `## What they expected`, `## What actually happened`, `## Steps
to see it`, `## How much this affects them`, `## What they attached`, then the collapsed
context sections, then a hidden `<!-- beacon-metadata {…} -->` JSON block that triage parses
(commit, reproducibility, step count, version). Labels set by the app: `beacon`,
`type:<kind>`, `impact:<impact>`, `area:<id>`. **Severity is never set by the app.**
`IssueRenderer.Labels` is the single vocabulary for both halves; triage's labels
(`needs-info`, `cannot-reproduce`, `expectation-mismatch`, `working-as-intended`,
`auto-fixed`, `needs-human`, `triaged`, `severity:*`) are listed there too.

`Redactor` (`Redaction.swift`) runs last over the issue text and every text attachment:
six credential shapes plus `hostSecrets` (short ones ignored), home directory → `~`. It
returns `RedactionFinding`s so the sheet can show what was masked.

---

## 4. The page

### 4.1 Views

One file, two faces, chosen at load from the query string:

- **Tester view** (default): the form. Kind picker, app picker, reporter, the
  kind-specific fields, images, area, impact, send. After send: a receipt with the
  reference. Never shows other reports.
- **Board** (`?view=board`): hides the form, shows every report newest first with filters
  (app, status, kind, free text) and a `<details>` per report rendering the full record.
  Images load on first open from the attachments subcollection.

The document `<title>` is "Beacon"; the board sets it to "Beacon reports" at runtime.

### 4.2 Query keys

Read from `location.search` into `ctx`. `BeaconInbox.Key` in `InboxLink.swift` is the Swift
side of the same contract, and `InboxLinkTests.everyKeyIsOneThePageReads` holds the two
lists equal — add a key in both places or that test fails.

`app` `bundle` `version` `build` `commit` `repo` `os` `osVersion` `device` `arch` `locale`
`tz` `appearance` `textSize` `reporter` `area` — plus `view=board`, which only the page
reads.

`app` matches an entry in the `apps` collection by id or by name, case-insensitively. When
the link also carries `version`, the picker is disabled (the link came from inside the app).

### 4.3 Storage schema

The artifact's database (the `db` capability): JSON documents at slash paths, 256 KiB per
document, last-writer-wins, org-internal.

```
apps/<id>                          seeded with write_db; the page never writes it
  name, platform, repository, folder, tracker ("github" | "board")

reports/<BN-reference>             written by the page on send; updated by the pickup
  reference, kind, filedAt (ISO), status, title, reporter (string), impact, area,
  app {id, name, repository, platform},
  body  — bug: {kind, whatHappened, expected, steps[], reproducibility}
        — feature-request: {kind, whatIWant, why}
        — feedback: {kind, message}
  context {app, bundle, version, build, commit, repository, os, osVersion, device,
           architecture, locale, timeZone, appearance, textSize}   (strings, "" when unknown)
  attachmentCount, userAgent, source: "beacon-inbox"
  — written back by the pickup:
  issueNumber, issueURL, issueFiledAt, status, finding {intent, citations[], verdict},
  triageNote, fixCommit, triagedAt, duplicateOf

reports/<BN-reference>/attachments/<n>    one document per image, n from 1
  filename, contentType ("image/jpeg"), dataURL, byteCount, width, height,
  originalByteCount, reference, order
```

Status values the page knows (the `STATUS` map): `new`, `filed`, `triaging`, `auto-fixed`,
`needs-human`, `needs-info`, `cannot-reproduce`, `working-as-intended`,
`expectation-mismatch`, `triaged`. Anything else renders as a grey pill with the raw value.

Images: shrunk in the browser with `createImageBitmap` + canvas to ≤1600 px on the long
edge, JPEG quality stepped 0.85 → 0.45 until ≤ 180 KiB (`IMAGE_TARGET_BYTES`), at most six
(`IMAGE_MAX_COUNT`). Each is its own document so the report stays small enough to list
without pulling pictures.

### 4.4 The doorbell

After the report and its images are written, the page calls
`artifact.publish({"data/doorbell.json": "{reference, filedAt}"})` — the files form of the
`artifact` capability, which mints a new version without reloading the sending view. **A
new version is what notifies a Claude session watching the artifact.** Database writes
alone notify nothing. If the publish is refused (`not_writer` for a viewer without edit
access, `capability_disabled`, …) the report is still safe in the database and the
scheduled pickup finds it; the page logs the code to the console and says nothing to the
tester.

### 4.5 Runtime facts the page relies on

- `claude.use("db")` and `claude.use("artifact")` resolve after the page's first run, or
  `null`; the page renders without them and shows the "can't reach the inbox" line when `db`
  is `null`.
- A `db` artifact is **organisation-internal**: every viewer is a signed-in member of the
  owner's Claude organisation. Sharing publicly is refused by the platform.
- `onSnapshot` on `reports` (board) and `apps` (both views) delivers live updates.
- The board's query is `orderBy("filedAt","desc").limit(500)`.

---

## 5. The pickup

### 5.1 Who runs it

| Runner | When | Can it… read the page | file issues | reproduce & fix Mac/iOS |
|---|---|---|---|---|
| An interactive Claude Code session that published or watched the artifact | Within ~1 minute of a doorbell publish | yes | yes (`gh`) | yes |
| A scheduled task built from `Triage/PICKUP.md` | On demand from the Scheduled section, or on a cron if one is set; only while the Claude app is open | yes | yes | yes |
| A cloud routine (verified 2026-09-04) | Cron, ≥1 hour, regardless of the Mac | yes — the Artifact tool is present and `read_db` worked | not yet: no `gh`, no git credentials; attaching a private repository as a source was refused (403) until the Claude GitHub App is installed on the organisation | no: Linux x86_64, no Swift |

### 5.2 The calls it makes

All through the Artifact tool (the session-side API to the page's database):

```
read_db   db_op=query  collection=reports  query.where=[["status","==","new"]]
read_db   db_op=list   collection=reports/<ref>/attachments  out_dir=<scratch>   → JSON files; decode dataURL
read_db   db_op=get    collection=apps  doc_id=<app.id>                         → repository, folder, tracker
read_db   db_op=query  collection=reports  query.where=[["app.id","==",<id>]]   → prior findings (the cache)
write_db  db_op=update collection=reports doc_id=<ref>  data={status, issueNumber, issueURL, …}
write_db  db_op=batch  writes=[{op:set, collection:apps, doc_id:<id>, data:{…}}, …]   (seeding apps)
```

And through `gh` for `tracker: "github"` apps:

```
gh issue list   --repo <owner/name> --label beacon --state all --limit 100 --json number,title,labels,body   (duplicate search)
gh issue create --repo <owner/name> --title … --label beacon --label type:<kind> --label impact:<impact> [--label area:<id>] --body …
gh issue comment <n> --repo … --body …          (a repeat report, "Also reported by …")
gh issue reopen  <n>                            (if the matching issue was closed)
gh issue edit    <n> --add-label triaged|auto-fixed|needs-human|…
gh issue close   <n>
```

Images for the issue are committed to the repository's `beacon-attachments` branch under
`.beacon/attachments/<ref>/` and linked under "What they attached", the same place
`GitHubIssueTransport` puts them (§6).

### 5.3 The order of work, as the task prompt states it

1. Query `new` reports. None → stop, no message.
2. Per report, oldest first: read images; look up the app; **read the board for prior
   findings on that app** and mark a match `duplicateOf` (comment on the existing issue,
   reuse status/finding/note); otherwise search issues for a duplicate, then create or
   comment; write `filed` + issue number back.
3. Work the open `beacon` issues on every app repository by the triage skill, `impact:
   blocked` first. Every outcome is written back onto the page report too (status,
   finding, triageNote for the founder, fixCommit, triagedAt).
4. For `tracker: "board"` apps: skip filing; work the report from its record; write the
   whole outcome onto it.
5. One message to the founder, through whatever NOTIFY names, only if something was filed or worked.

The reference deployment's standing rule (owner's decision, 2026-09-04): gate 4's size limits are relaxed — fix
everything that reproduces — but the blast-radius list still holds.

### 5.4 The watch

`Artifact action=status` shows whether this session holds a connected watch on the
artifact. A publish from the session arms one; `action=watch` re-arms it. Watches are
session-local and survive `--resume` for the most recently used artifact. Whether the
doorbell publish actually reached a session has **not** been observed yet: the first real
send (BN-8EA6C3, 2026-09-07) happened while a watch showed connected, and no republish
notice was seen. The scheduled task is the floor regardless.

---

## 6. The native route

### 6.1 Transports (`BeaconGitHub/Transports.swift`)

`ReportTransport` (in Core): `destinationDescription` for the review screen, and
`submit(ReportSubmission) async throws -> SubmissionReceipt`. `ReportSubmission` carries
the report, the rendered `IssueDraft`, and the swept attachments. `SubmissionReceipt`
carries `summary`, `issueNumber?`, `url?`, `isFiled` — a transport that saved locally must
return `isFiled: false`, and there is a test for it.

| Transport | Needs | Does |
|---|---|---|
| `GitHubIssueTransport(client:attachmentBranch:)` | A token with `repo` scope | `ensureBranch`, `putFile` each attachment under `.beacon/attachments/<ref>/`, insert the links, `createIssue` |
| `RelayTransport(endpoint:appToken:destinationName:)` | A service you run | `POST` JSON `{title, body, labels, reference, account, attachments:[{filename, base64}]}` with `Authorization: Bearer <appToken>`; expects `{issue_number, html_url}`; checks encoded size against `AcceptedFormats.maximumTotalBytes` (60 MiB) first |
| `LocalBundleTransport(folderProvider:)` | Nothing | Reports the folder `ReportArchive` already wrote; `isFiled: false` |
| `FallbackTransport(primary:fallback:onFallback:)` | — | Tries primary, on error calls the fallback and says so in the receipt |

Every report is written to `reportArchiveDirectory` by `ReportArchive.save` **before** any
transport runs: `report.json`, `issue.md`, and the attachment bytes, in a folder named by
the reference.

### 6.2 GitHub REST calls (`GitHubClient.swift`)

Base `https://api.github.com`, `Authorization: Bearer <token>`, JSON. Only published
endpoints — the comment in the file says why.

| Method | Path | Used for |
|---|---|---|
| `POST` | `repos/{owner}/{repo}/issues` `{title, body, labels}` | `createIssue` → `{number, html_url}` |
| `GET` | `user` | `currentLogin` |
| `PUT` | `repos/{owner}/{repo}/contents/{path}` `{message, content(base64), branch}` | `putFile` → `content.html_url` |
| `GET` | `repos/{owner}/{repo}/git/ref/heads/{branch}` | `ensureBranch` — exists? |
| `GET` | `repos/{owner}/{repo}` | default branch name (never assumed) |
| `POST` | `repos/{owner}/{repo}/git/refs` `{ref, sha}` | create the attachment branch from the default branch's head |

`GitHubClient.explain(status, message)` turns 401/403/404/422/5xx into sentences the
reporter can act on; `TransportTests` covers them.

### 6.3 Device flow (`DeviceFlow.swift`)

`GitHubDeviceFlow(clientID:scopes: ["repo"])`. `begin()` posts to
`https://github.com/login/device/code` and returns `Challenge {deviceCode, userCode,
verificationURL, interval, expiresAt}`; `awaitToken(challenge)` polls
`https://github.com/login/oauth/access_token` at the interval, handling
`authorization_pending`, `slow_down`, `expired_token`, `access_denied`. The client id is
public by design; there is no client secret. `GitHubTokenStore.save/read/delete(account:,
service: "beacon.github")` is the keychain wrapper. **No OAuth app is registered yet** —
registering one is the adopter's own step (`docs/setup-github.md`, step 2), and it is done under the adopter's own sign-in.

### 6.4 Diagnostics (`BeaconDiagnostics`)

- `BeaconLog.shared`: an in-memory ring (capacity, eviction, tail, level filter,
  categories via `.category("sync")`). The host writes to it; the last
  `logTailLineCount` lines ride on every report.
- `EnvironmentProbe.snapshot()`: OS name/version, `hw.model` via `sysctl`, architecture,
  locale, time zone, memory, free disk, appearance/text size/reduced motion per platform,
  and whether `SystemLanguageModel.default` is available (read as state, never invoked).
- `FileTreeScanner`: `contentsOfDirectory` + `resourceValues` only; never opens a file;
  bounded by `maximumDepth`/`maximumEntries`, skips `FileTreeRoot.defaultSkips`, says
  `truncated` out loud, redacts the root path.
- `ContextCollector(configuration:log:).collect()` assembles `ReportContext`.
- `ReportArchive(directory:)`: `save(_:) -> SavedReport {folder, reportJSON, issueMarkdown,
  attachments}`, `saved() -> [URL]`.

### 6.5 Capture (`BeaconCapture`)

Three names, the same on both platforms, so `FeedbackSession` has one code path:
`ScreenPermission.ensure()`, `ScreenCapturer().screenshot()`, `ScreenRecording.start(
maximumSeconds:)` / `finish()` / `cancel()`.

- **macOS** (`MacCapture.swift`): ScreenCaptureKit. `SCShareableContent.currentProcess`
  (own windows only), `capturesAudio = false`, `SCRecordingOutput` to an `.mp4`.
  `ScreenPermission` wraps the one-time Screen Recording prompt. Not yet run against a
  real window (STATUS.md).
- **iOS** (`IOSCapture.swift`): the screenshot is `UIGraphicsImageRenderer` over the key
  window's root view controller's view with `drawHierarchy` — the presented sheet lives
  beside that view in the window, so the picture shows the app and not the form. The
  recording is `RPScreenRecorder.shared()` with microphone and camera off, stopped with
  `stopRecording(withOutput:)` to a `.mov`; declining the system prompt maps to
  `CaptureError.permissionDenied`. iOS has no preflight, so `ScreenPermission.ensure()`
  only reports `isAvailable`.
- **Shared** (`Capture.swift`): `CaptureError` (sentences name the platform through
  `PlatformWording`), `RecordingFrames.extract(from:count:)` (AVAssetImageGenerator, six
  frames a beat in from each end, long edge capped at 1600), `PickedMedia.attachments(
  data:type:)` for a photo or video from the library — images are re-encoded from their
  pixels so location and camera metadata never reach the report, and a video gets frames
  like a recording does.

The session applies the size limits in one place (`admit(_:)`) whatever produced the
attachments, and stops a forgotten recording itself at `maximumRecordingSeconds`. A
recording failure is kept on the session (`recordingProblem`) because on iOS the view
that pressed stop is the strip the sheet collapsed to, and it is gone by the time the
answer arrives.

On iOS the sheet collapses to `BeaconSheet.recordingDetent` while recording, with
`presentationBackgroundInteraction(.enabled)` so the app is usable behind it and
`interactiveDismissDisabled` so a swipe cannot lose the recording and the form.

### 6.6 The on-device pass (`BeaconIntelligence`)

`CompletenessReviewing` protocol; `OnDeviceCompletenessReviewer` uses Foundation Models
with `@Generable` output (`readsAsComplete`, up to three `CompletenessQuestion`s);
`NoReviewer` where unavailable, producing `CompletenessReview.notReviewed` with
`source: .unavailable` so a report says it wasn't reviewed rather than implying it was.
Questions are advisory; the sheet always offers "send it anyway".

### 6.7 Consent

`ConsentNotice.current` is versioned data; `naming(organizationName)` fills the org in;
acceptance is stored per version and per reporter through `ConsentStoring`
(`UserDefaultsConsentStore` by default). Rewording bumps the version and re-asks.

---

## 7. The indexer

```
swift run beacon-index --source <dir> --output <file> [--app-name <name>] [--overrides <file>] [--commit <sha>] [--quiet]
```

Reads the host's source tree, finds build units (SwiftPM targets, Xcode targets, top-level
folders) and the screens inside them (types ending in `View`, un-camel-cased, "View"
dropped), and writes `BeaconIndex.json` (`schemaVersion` 1). The overrides file renames,
hides (`hiddenFromReporters` — routable, not offered), absorbs, adds `extraAreas`, and
ignores paths. `BeaconIndex.loadFromBundle(_:)` refuses a newer schema. CI runs the indexer
on this package itself and fails if the output is empty.

---

## 8. Seeding and reproduction

`BeaconSeed.applyIfRequested(...)` copies a folder over the app's data directory at launch
**only** when both `BEACON_SEED_ENABLE=1` and `BEACON_SEED_DIRECTORY=<path>` are set; a
missing folder is safe; every outcome returns a `Result {applied, explanation}`.
`isReproductionRun` tells the host it is being driven. Keep one seed per common shape
under `Triage/seeds/`.

`beacon-reproduce.yml` (`workflow_dispatch` with `issue`, `commit`, `seed`) runs on the
pinned `macos-26` runner and is shipped **deliberately failing at the run step** until it is
pointed at a host app's UI test scheme. `beacon-triage.yml` runs the skill on Linux on a
weekday cron and hands the macOS leg to it. Costs and runner facts are in
CLOUD-REPRODUCTION.md.

---

## 9. Operating the live page

- **Republish** after any edit to `Inbox/index.html`: the Artifact tool with `file_path`
  set to the file and `url` set to the artifact. Omit `capabilities` to carry `db` and
  `artifact` forward; omit `favicon` (it is 🎇 and must not change). The publishing
  session's watch stays connected.
- **Add an app**: one `write_db` set on `apps/<id>` with `name, platform, repository,
  folder, tracker`. No republish; the picker and the board read the collection live.
- **Move an app off GitHub**: `write_db update apps/<id> {tracker: "board"}`.
- **Labels on a new repository**: `Scripts/beacon-labels.sh <owner/repo>` (needs `gh`
  signed in).
- **Give a tester access**: share the artifact from the page's share menu with edit
  access (edit is what lets the doorbell publish; view-only can still send, and the
  scheduled pickup finds the report).
- **Inspect the store from a session**: `read_db list reports`, `read_db get reports/<ref>`,
  `read_db list reports/<ref>/attachments --out_dir …`.
- The artifact is owned by the Claude account this repository's sessions run under.
  Another account — even the same email in another organisation — gets "Page not found".

---

## 10. Known gaps, in one place

- The native route's direct transport is proven (`LiveTransportTests`, 2026-09-07, against a private repository), but the device flow has never been run: no OAuth App is registered. No relay is deployed.
- The on-device model has never reviewed a real report; the prompt will need tuning (it
  ran on the iOS Simulator on 2026-09-07 and asked nothing about a short, complete bug).
- Recording has never captured a real window on the Mac, and never produced a video on
  iOS: the simulator's ReplayKit starts and stops but writes an empty file, so a physical
  device is needed for that proof.
- The iOS build is not in CI; `ci.yml` builds and tests on macOS only.
- The doorbell publish waking a session has not been observed (§5.4).
- A cloud routine can read and file but cannot build, fix or reach private repos (§5.1).
- The page carries no log tail, settings or folder shape — by design until Beacon is
  offered to others (owner's decision, 2026-09-04).
- `expectation-mismatch` opens a second issue by policy; the pickup prompt does not yet
  spell out the second issue's fields.

---

## 11. Tests

`swift test` — 93 tests, 22 suites, Swift Testing (one skipped unless pointed at a repository).
On the iOS Simulator: `xcodebuild test -scheme Beacon-Package -destination 'platform=iOS
Simulator,name=iPhone Air'` — the same suites plus one iOS-only test, 94.

| Target | Covers |
|---|---|
| `BeaconCoreTests` | Completeness (the gate, placeholders, the non-blocking nudge), rendering (headings, verbatim quoting, labels, no severity, title truncation, metadata JSON), redaction (six shapes, host secrets, prose untouched, home dir), seeding (both switches), the inbox link (keys, blanks left out, existing query kept, key list equals the page's), platform wording (the noun per platform, capitalised forms, the network-failure sentence goes through it) |
| `BeaconDiagnosticsTests` | The log ring, the environment probe (on iOS: the device model, never the architecture; text size and appearance present; the simulator's model read from the environment), the folder scan (**contents never read** — a known string is written and asserted absent), the archive |
| `BeaconGitHubTests` | Transports: local never claims filed, fallback takes over and says why, attachment links don't disturb prose, status codes become sentences. `LiveTransportTests` files a real issue with an attachment and runs only with `BEACON_LIVE_GITHUB_REPO` and `BEACON_LIVE_GITHUB_TOKEN` set |
| `BeaconIntelligenceTests` | Unavailability is honest, questions override the model's flag, blank questions dropped, unknown field falls back |
| `BeaconCaptureTests` | Frames out of a real video (PNG, time order, at least two, none from a non-video), a picked video travels with frames, a picked photo loses its GPS and camera metadata, unreadable formats turned away, the capture sentences name the platform |

The page has no automated tests. Its script is syntax-checked before publish with
`node -e "new Function(<script body>)"`; behaviour is verified by sending a report.

---

## 12. Conventions

- Every documentation page carries `*Last updated: YYYY-MM-DD*` under its title; move the
  date when you change the page.
- One vocabulary: kinds, impacts, statuses and labels are defined once
  (`IssueRenderer.Labels`, the page's `STATUS`) and copied nowhere else without a test
  holding the copies equal.
- Facts about the deployment — the page URL, a repository, a folder, a branch — arrive
  from configuration or are asked of the system; none is a literal at a use site.
- Every commit is pushed the same session. Work happens on `main` for this package.
- A change to `BeaconUI`, `BeaconCapture` or `BeaconDiagnostics` is built for the iOS
  Simulator as well as the Mac before it is committed (`xcodebuild build -scheme Beacon
  -destination 'generic/platform=iOS Simulator'`); CI builds only the Mac today. Platform
  differences live behind one shared name, never behind `#if` in a view body unless the
  platform genuinely lacks the control (`exclusiveChoiceStyle()`, `FlowingButtons`).
- Anything a reporter sees that names the machine goes through `PlatformWording`.
- A change to the sheet is walked in `Examples/BeaconExample` on the platform it touches;
  "compiles" is not "shown".
