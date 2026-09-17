# Developer guide

*Last updated: 2026-09-17*

The technical reference for changing Beacon itself: the Swift package, the page, the pickup and the workflows. To add Beacon to an app, read [the options reference](../docs/options.md) and [GitHub setup](../docs/setup-github.md) instead. What Beacon collects is in [What is collected](../docs/what-is-collected.md), and testers have [their own page](../docs/for-testers.md). What is proven and what is not is in [STATUS.md](STATUS.md).

Beacon has two ways into one queue of reports. The **page** is a web form published as a Claude artifact; the app opens it with the machine's details in the link. The **native sheet** is a SwiftUI flow inside the app that collects diagnostics, captures the screen and files a GitHub issue through a transport. A Claude session, the **pickup**, turns page reports into GitHub issues and works every report by `Triage/TRIAGE.md`.

## Parts

| Part | What it does | Where it lives |
|---|---|---|
| `BeaconCore` | Report values, completeness rules, issue rendering, secret sweep, consent, the transport protocol, the app map, the inbox link, seeding, `PlatformWording`. No UI, no platform APIs | `Sources/BeaconCore` |
| `BeaconDiagnostics` | The log ring, environment probe, folder scan, context collector, report archive | `Sources/BeaconDiagnostics` |
| `BeaconIntelligence` | The on-device completeness check on Foundation Models | `Sources/BeaconIntelligence` |
| `BeaconCapture` | Screenshots, screen recording, frames from video, picked photos and videos | `Sources/BeaconCapture` |
| `BeaconGitHub` | `GitHubClient`, device flow, keychain token store, the four transports | `Sources/BeaconGitHub` |
| `BeaconUI` | `BeaconSheet`, `FormSteps`, `FeedbackSession`, `BeaconWalkthrough` | `Sources/BeaconUI` |
| `Beacon` | What a host imports: `Beacon.configure`, the view modifiers, `BeaconReportButton`, `BeaconInboxButton` | `Sources/Beacon` |
| `beacon-index` | CLI that writes the app map, `BeaconIndex.json` | `Sources/beacon-index` |
| The page | Tester form and the board, in one file | `Inbox/index.html` |
| The policy and pickup prompt | Rule documents an agent follows | `Triage/TRIAGE.md`, `Triage/PICKUP.md` |
| Skills | `beacon-setup` and `beacon-triage` | `.claude/skills/` |
| Plugin | `plugin.json`, whose `skills` points at `./.claude/skills`, and `marketplace.json`, pinned to the release tag | `.claude-plugin/` |
| Workflows | `ci.yml` for this repository; `beacon-triage.yml` and `beacon-reproduce.yml` to copy into an app repository | `.github/workflows/` |
| Issue forms | Bug and feature forms for people filing by hand | `.github/ISSUE_TEMPLATE/` |
| Scripts | `beacon-labels.sh` creates the labels; `beacon-adopt-github.sh` copies the GitHub pieces into an app repository and runs it | `Scripts/` |
| Example app | The smallest host, for iPhone, iPad and Mac, built from `project.yml` with xcodegen. Reports go to `LocalBundleTransport` | `Examples/BeaconExample` |
| Tests | Five targets, one per library target except `BeaconUI` and `Beacon` | `Tests/` |

`Package.swift` uses Swift tools 6.2 and targets macOS 26 and iOS 26. Products: `Beacon` and `BeaconCore` (libraries) and `beacon-index` (executable).

Each target imports only the targets above it in the table. `BeaconDiagnostics`, `BeaconIntelligence`, `BeaconCapture` and `BeaconGitHub` depend only on `BeaconCore`. `BeaconUI` depends on all five, and `Beacon` depends on `BeaconUI`. `Beacon` re-exports `BeaconCore`, `BeaconDiagnostics` and `BeaconGitHub`, so `import Beacon` is the only import a configuration call needs.

## Contents

1. [The report](#the-report)
2. [Completeness rules](#completeness-rules)
3. [Issue rendering and labels](#issue-rendering-and-labels)
4. [Secret sweep](#secret-sweep)
5. [The page](#the-page)
6. [The pickup](#the-pickup)
7. [The native sheet](#the-native-sheet)
8. [Transports](#transports)
9. [GitHub calls](#github-calls)
10. [Diagnostics](#diagnostics)
11. [Capture](#capture)
12. [On-device check](#on-device-check)
13. [Consent](#consent)
14. [The indexer](#the-indexer)
15. [Seeding and reproduction](#seeding-and-reproduction)
16. [Operating the page](#operating-the-page)
17. [Tests](#tests)
18. [Conventions](#conventions)
19. [Decisions](#decisions)

## The report

`FeedbackReport` in `BeaconCore/Report.swift` is the one shape every stage works on.

```
FeedbackReport
  id: UUID                 reference = "BN-" + first 6 characters of id, uppercased
  startedAt: Date          when the session started, not when the reporter sent
  reporter: Reporter       accountID (required), displayName?, contact?
  title: String            blank means the renderer derives one
  body: ReportBody         .bug(BugBody) | .feature(FeatureBody) | .feedback(FeedbackBody)
  impact: Impact           blocked | slowed | irritating | noticed   (rank 0..3, 0 is worst)
  areaID: String?          an area id from BeaconIndex, or "not-sure" / "something-new"
  attachments: [Attachment]
  context: ReportContext   app, environment, settings, fileTrees, log, hostNotes
  consentVersion: String   the ConsentNotice version the reporter accepted
  review: CompletenessReview?

BugBody       whatHappened, expected, steps [String], reproducibility (every-time | sometimes | once | unknown)
FeatureBody   whatIWant, why, areaID?, isNewArea
FeedbackBody  message, areaID?
FeedbackKind  bug | feature-request | feedback
Severity      critical | high | medium | low   (set by triage only)
```

`impact` defaults to `slowed`. `Reporter.accountID` is required because an anonymous report cannot be followed up.

## Completeness rules

`CompletenessRules` in `Completeness.swift` is the deterministic gate. A blocking issue stops a send. A non-blocking issue is shown and the reporter can still send.

| Kind | Field | Rule | Blocks |
|---|---|---|---|
| Bug | `whatHappened` | Not empty, not a placeholder, at least 12 characters | Yes |
| Bug | `expected` | Not empty, not a placeholder, at least 12 characters | Yes |
| Bug | `steps` | At least one non-blank step; a single step is at least 12 characters; not every step a placeholder | Yes |
| Bug | `reproducibility` | `unknown` gets a nudge to try again | No |
| Feature | `whatIWant` | Not empty, not a placeholder, at least 12 characters | Yes |
| Feature | `why` | Empty or a placeholder gets a prompt | No |
| Feature | area | An area is picked, or `isNewArea` is set | Yes |
| Feedback | `message` | Not empty, not a placeholder, at least 12 characters | Yes |

`minimumMeaningfulCharacters` is 12. A placeholder is an answer such as "n/a", "idk", "asdf" or "it broke", matched whole and case-insensitively after trimming punctuation. The full list is `CompletenessRules.placeholders`.

The page carries a copy of these rules and their messages in JavaScript. Change `Completeness.swift` first, then `Inbox/index.html`, and keep the messages identical. The page also requires a reporter name of at least 3 characters and a chosen app. It has no area rule for feature requests.

## Issue rendering and labels

`IssueRenderer.render` in `IssueRendering.swift` turns a report into `IssueDraft {title, body, labels}`.

**Title.** The reporter's title, or the first sentence of `whatHappened`, `whatIWant` or `message`, cut on a word boundary at 72 characters. A real area adds a `[Area name] ` prefix.

**Body**, in order:

1. A quoted line naming the reporter and saying they agreed to be contacted.
2. The kind's sections. Bug: `## What they expected`, `## What actually happened`, `## Steps to see it`, `## Does it happen again?`. Feature: `## What they want to be able to do`, a `## Why` section when `why` is set, `## Where it belongs` (with the area's source paths). Feedback: `## What they said`.
3. `## How much this affects them`.
4. `## What they attached`, when there are attachments.
5. Collapsed `<details>` blocks: app, machine and settings; one per folder listing; the log tail.
6. `## Checked before sending`, when the on-device check ran and asked questions.
7. A hidden `<!-- beacon-metadata {...} -->` JSON block that triage parses.

The reporter's words are quoted verbatim, every line prefixed with `> `.

Metadata keys: `beacon_schema` (`"1"`), `report_id`, `reference`, `kind`, `impact`, `area`, `account`, `app_version`, `app_build`, `consent_version`, `started_at`, plus `commit`, `reproducibility`, `step_count` and `review_source` when they apply. Every value is a string.

**Labels** set by the app: `beacon`, `type:<kind>`, `impact:<impact>`, and `area:<id>` unless the area is `not-sure`. The app never sets `severity:*`.

`IssueRenderer.Labels` holds the whole label vocabulary, including the labels triage sets: `needs-info`, `cannot-reproduce`, `expectation-mismatch`, `working-as-intended`, `auto-fixed`, `needs-human`, `triaged` and `severity:*`. `Scripts/beacon-labels.sh <owner/repo>` creates all of them except `area:*` on a repository.

## Secret sweep

`Redactor` in `Redaction.swift` replaces each match with `[removed by Beacon]` and returns a `RedactionFinding` naming what it looked like and where.

- **Patterns**: 13 credential shapes, including Anthropic, OpenAI-style, GitHub, AWS, Google, Slack and Stripe keys, private key blocks, bearer tokens, JSON web tokens, `password=`-style settings and URLs with a password.
- **Host secrets**: strings from `BeaconConfiguration.hostSecrets`. Values shorter than 8 characters are ignored.
- **Text attachments**: files whose extension is in `AcceptedFormats.textExtensions` are swept. Images, PDFs and video pass through unchanged.
- **Paths**: `Redactor.redactHome` turns the home directory into `~`.

The sheet sweeps attachments first, then the rendered issue body. The done screen lists the findings.

## The page

`Inbox/index.html` is one file published as a Claude artifact with the `db` and `artifact` capabilities. What a tester sees is in [the testers' page](../docs/for-testers.md), and the board is described in [The board](../docs/the-board.md).

### Views

- **Tester view** (default): the form, then a receipt with the reference. It never shows other reports.
- **Board** (`?view=board`): every report, newest first, with filters for app, status and kind, and a text search. Each report expands to the full record. Images load the first time a report is opened. The board sets the document title to "Beacon reports".

### Query keys

The page reads these keys from the link, and `BeaconInbox.Key` in `InboxLink.swift` is the Swift side of the same list:

`app` `bundle` `version` `build` `commit` `repo` `os` `osVersion` `device` `arch` `locale` `tz` `appearance` `textSize` `reporter` `area`

They fill the page's `ctx` object, except `app`, which picks the app, and `reporter` and `area`, which fill form fields. A missing `locale` falls back to the browser language and a missing `tz` to the browser time zone. `view=board` is read only by the page. `BeaconInbox.url` leaves out empty values and keeps any query the page URL already had. `InboxLinkTests.everyKeyIsOneThePageReads` compares `BeaconInbox.Key` against a list copied from the page, so add a new key to the page, the enum and that list together.

`app` matches an app by id or by name, case-insensitively. When the link also carries `version`, the app picker is locked.

### Storage

The artifact's database holds JSON documents at slash paths. A document is at most 256 KiB. Writes are last-writer-wins.

```
apps/<id>                          seeded with write_db; the page never writes it
  name, platform, repository, folder, tracker ("github" | "board")

reports/<BN-reference>             written by the page on send
  reference, kind, filedAt (ISO 8601), status ("new"), title, reporter (string),
  impact, area, attachmentCount, userAgent, source ("beacon-inbox"),
  app {id, name, repository, platform},
  body   bug: {kind, whatHappened, expected, steps[], reproducibility}
         feature-request: {kind, whatIWant, why}
         feedback: {kind, message}
  context {app, bundle, version, build, commit, repository, os, osVersion, device,
           architecture, locale, timeZone, appearance, textSize}   strings, "" when unknown
  written by the pickup:
  status, issueNumber, issueURL, issueFiledAt, finding {intent, citations[], verdict},
  triageNote, fixCommit, triagedAt, duplicateOf

reports/<BN-reference>/attachments/<n>    one document per image, n from 1
  filename, contentType ("image/jpeg"), dataURL, byteCount, width, height,
  originalByteCount, reference, order
```

The page reads `name`, `repository` and `platform` from `apps`. Only the pickup reads `folder` and `tracker`. The page's reference is `BN-` plus 3 random bytes in uppercase hex, so it has the same form as the sheet's reference.

The page knows these status values (its `STATUS` map): `new`, `filed`, `triaging`, `auto-fixed`, `needs-human`, `needs-info`, `cannot-reproduce`, `working-as-intended`, `expectation-mismatch`, `triaged`. Any other value renders as a grey pill showing the raw value. The board wording for each is in [How it works](../docs/how-it-works.md).

**Images.** The browser shrinks each image with `createImageBitmap` and a canvas to at most 1600 px on the long edge (`IMAGE_MAX_EDGE`). It encodes JPEG at quality 0.85, 0.75, 0.65, 0.55 then 0.45 until the result is at most 180 KiB (`IMAGE_TARGET_BYTES`), and refuses the image if it is still larger. A report holds at most six images (`IMAGE_MAX_COUNT`). Images come from the file picker (`accept="image/*"`) or a paste. Each image is its own document so the board can list reports without loading pictures.

### The doorbell

After the report and its images are written, the page calls:

```js
artifact.publish({ "data/doorbell.json": JSON.stringify({ reference, filedAt }) })
```

This is the files form of `publish`. It mints a new artifact version and leaves the sending view running. A Claude Code session watching the artifact is told about new versions; database writes alone are not new versions.

If the publish is refused (`not_writer`, `capability_disabled` or another code), the report is already in the database and a scheduled pickup finds it. The page logs the code to the console and shows the tester the normal receipt.

### Runtime facts

- `claude.use("db")` and `claude.use("artifact")` resolve after the script's first run, or to `null`. The page renders without them. When `db` is `null`, it shows the "can't reach the inbox" line.
- An artifact that declares `db` is organization-internal. Every reader and writer is a signed-in member of the owner's Claude organization, and it cannot be shared publicly.
- By default only viewers with "Can interact" or higher write shared documents. A view-only viewer cannot send a report.
- Publishing a version needs "Can edit". A tester with "Can interact" can send, but the doorbell is refused with `not_writer`.
- The board subscribes with `onSnapshot` to `reports`, ordered by `filedAt` descending, limit 500. Both views subscribe to `apps`, ordered by `name`.

## The pickup

The pickup is a Claude session that follows `Triage/PICKUP.md`. The prompt has four values to fill in: `BEACON_PAGE`, `BEACON_REPO`, `CODE_ROOT` and `NOTIFY`.

| Runner | When it runs | Local files and tools |
|---|---|---|
| An interactive Claude Code session watching the artifact | When the doorbell publishes a new version | Yes |
| A Desktop scheduled task | On its schedule, minimum interval 1 minute, while the machine is on | Yes |
| A cloud routine | On its schedule, minimum interval 1 hour | No: a fresh clone of the repository |

The database calls go through `read_db` and `write_db` (in Claude Code, the `ArtifactData` tool):

```
read_db   query  collection=reports  where=[["status","==","new"]]
read_db   list   collection=reports/<ref>/attachments  out_dir=<scratch>   (decode each dataURL)
read_db   query  collection=reports  where=[["app.id","==",<id>]]          (earlier findings for duplicates)
write_db  update collection=reports  doc_id=<ref>  data={status, issueNumber, issueURL, issueFiledAt, ...}
write_db  set    collection=apps     doc_id=<id>   data={name, platform, repository, folder, tracker}
```

The GitHub calls, for apps with `tracker: "github"`:

```bash
gh issue list --repo <owner/name> --label beacon --state all --limit 100 --json number,title,labels,body
gh issue create --repo <owner/name> --title ... --label beacon --label type:<kind> --label impact:<impact> --body ...
gh issue comment <n> --repo <owner/name> --body ...
gh issue list --repo <owner/name> --label beacon --state open --search "-label:triaged -label:needs-info"
```

Order of work, as the prompt states it:

1. Query reports with status `new`. For each, oldest first, read its images and its app.
2. Compare it with earlier reports for the same app that carry a finding. On a match, set `duplicateOf`, copy the status, finding and note, and comment on the existing issue.
3. Otherwise search the repository's `beacon` issues. On a match, comment and reopen if closed. With no match, create the issue. Commit images to the `beacon-attachments` branch under `.beacon/attachments/<reference>/` and link them.
4. Write `status: "filed"`, `issueNumber`, `issueURL` and `issueFiledAt` back to the report.
5. Work the open `beacon` issues by the triage skill, `impact:blocked` first. Write every outcome back to the page report: status, finding, triageNote, fixCommit, triagedAt.
6. For apps with `tracker: "board"`, skip GitHub and work each new report from its record.
7. Send one message to `NOTIFY` only if something was filed or worked.

## The native sheet

`FeedbackSession` in `BeaconUI/FeedbackSession.swift` owns one report from start to finish. Its steps: `consent`, `pickKind`, `form`, `review`, `questions`, `sending`, `done`, and `noReporter` when `currentReporter` returns `nil`.

On send, the session:

1. Runs the on-device check once, if it is available. If it returns questions, it shows them. Answers are appended to the matching field, never replacing it.
2. Sweeps every attachment for secrets.
3. Renders the issue, then sweeps its body.
4. Saves the report with `ReportArchive.save` to `reportArchiveDirectory`.
5. Calls the transport. On an error, the receipt says the report is saved and where, with `isFiled: false`.

`admit(_:)` applies the size limits to every attachment, whatever produced it: 25 MiB per file (`AcceptedFormats.maximumFileBytes`) and 60 MiB in total (`maximumTotalBytes`). The session stops a recording itself at `maximumRecordingSeconds` (default 180). A recording failure is kept on the session as `recordingProblem`, because on iOS the view that pressed stop is gone by the time the answer arrives.

On iOS, while recording, the sheet shrinks to `BeaconSheet.recordingDetent` (112 points high). It sets `presentationBackgroundInteraction(.enabled)` so the app is usable behind it, and `interactiveDismissDisabled` so a swipe cannot lose the recording.

## Transports

`ReportTransport` (in `BeaconCore`) has `destinationDescription`, shown on the review screen, and `submit(ReportSubmission) async throws -> SubmissionReceipt`. `ReportSubmission` carries the report, the rendered `IssueDraft` and the swept attachments. `SubmissionReceipt` carries `summary`, `issueNumber?`, `url?` and `isFiled`.

| Transport | Needs | Does |
|---|---|---|
| `GitHubIssueTransport(client:attachmentBranch:)` | A GitHub token for the repository; the device flow asks for the `repo` scope | Ensures the branch (default `beacon-attachments`), puts each attachment at `.beacon/attachments/<reference>/<filename>`, turns the filenames into links, creates the issue |
| `RelayTransport(endpoint:appToken:destinationName:)` | A service you run | Checks the base64 size of the attachments against 60 MiB, then `POST`s JSON `{title, body, labels, reference, account, attachments: [{filename, base64}]}` with `Authorization: Bearer <appToken>` when set. Reads `issue_number` and `html_url`, or `error` on failure |
| `LocalBundleTransport(folderProvider:handoverInstruction:)` | Nothing | Returns the folder from `folderProvider` with `isFiled: false` |
| `FallbackTransport(primary:fallback:onFallback:)` | Two transports | Tries `primary`. On an error, calls `onFallback`, submits to `fallback` and prefixes the receipt summary with why |

The archive folder is `<yyyy-MM-dd-HHmmss>-<reference>` inside `reportArchiveDirectory`. It holds `report.json` (without attachment bytes), `issue.md` (title, labels and body) and `attachments/` with each file under a flattened name. The default directory is `Application Support/<app name>/Beacon/reports`.

## GitHub calls

`GitHubClient` in `GitHubClient.swift` calls `https://api.github.com` with `Authorization: Bearer <token>`, `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28`. It uses only published endpoints.

| Method | Path | Used by |
|---|---|---|
| `POST` | `repos/{owner}/{repo}/issues` with `{title, body, labels}` | `createIssue`, returns `number` and `html_url` |
| `GET` | `user` | `currentLogin` |
| `PUT` | `repos/{owner}/{repo}/contents/{path}` with `{message, content (base64), branch}` | `putFile`, returns `content.html_url` |
| `GET` | `repos/{owner}/{repo}/git/ref/heads/{branch}` | `ensureBranch`: does the branch exist, and the default branch's head |
| `GET` | `repos/{owner}/{repo}` | `ensureBranch`: the default branch name |
| `POST` | `repos/{owner}/{repo}/git/refs` with `{ref, sha}` | `ensureBranch`: create the branch from the default branch's head |

`GitHubClient.explain(status, message)` turns a failed status into a sentence a reporter can act on:

| Status | Meaning given |
|---|---|
| 401 | The sign-in expired |
| 403 with "rate limit" in the message | Rate-limited, the report is saved, try again in a few minutes |
| 403 | The account cannot file into that repository |
| 404 | The repository cannot be found or seen |
| 410 | Issues are switched off on that repository |
| 422 | GitHub refused the report as written, with its message |
| Other | GitHub's own message |

## Device flow

`GitHubDeviceFlow(clientID:scopes:)` in `DeviceFlow.swift` signs a reporter in without a client secret. `scopes` defaults to `["repo"]`.

- `begin()` posts to `https://github.com/login/device/code` and returns `Challenge {userCode, verificationURL, deviceCode, expiresAt, pollInterval}`. Missing values default to 900 seconds to expire and a 5-second interval.
- `awaitToken(_:)` polls `https://github.com/login/oauth/access_token`. `authorization_pending` keeps polling, `slow_down` adds 5 seconds to the interval, `access_denied` throws `declined`, and `expired_token` throws `expired`.
- `GitHubTokenStore.save`, `read` and `delete` keep the token in the keychain as a generic password, service `beacon.github`, accessible after first unlock.

The adopter registers the OAuth app under their own account. The steps are in [GitHub setup](../docs/setup-github.md).

## Diagnostics

- **`BeaconLog.shared`**: an in-memory ring, default capacity 2000 lines (minimum 50), default minimum level `info`. Each line also goes to the system log under its category. `category("sync")` returns a writer for one category. The last `logTailLineCount` lines (default 400) ride on every report.
- **`EnvironmentProbe.snapshot()`**: OS name and version, device model, architecture, locale, time zone, memory, free disk, and whether `SystemLanguageModel.default` is available, read as state without running the model. On macOS it adds appearance and reduced motion, and on iOS also text size. The model is `hw.model` on macOS, and `hw.machine` on iOS. In the iOS Simulator it is `SIMULATOR_MODEL_IDENTIFIER` plus ` (Simulator)`.
- **`FileTreeScanner.scan`**: calls `contentsOfDirectory` and `resourceValues` only and never opens a file. It walks breadth-first, bounded by `maximumDepth` (default 4) and `maximumEntries` (default 800). Directories in `FileTreeRoot.defaultSkips` are listed as `(skipped)` and not walked. It sets `truncated` when it stops early and redacts the root path.
- **`ContextCollector(configuration:log:).collect()`**: assembles `ReportContext`, with the folder scan off the main actor.
- **`ReportArchive(directory:)`**: `save(_:)` returns `SavedReport {folder, reportJSON, issueMarkdown, attachments}`. `saved()` lists saved folders, newest first.

## Capture

`MacCapture.swift` and `IOSCapture.swift` present the same three names, so `FeedbackSession` has one code path: `ScreenPermission.ensure()`, `ScreenCapturer().screenshot()`, and `ScreenRecording.start(maximumSeconds:)` with `finish()` and `cancel()`.

| | macOS | iOS |
|---|---|---|
| Screenshot | ScreenCaptureKit, `SCShareableContent.currentProcess`, the largest on-screen window over 80 points in each direction | `UIGraphicsImageRenderer` over the key window's root view controller's view with `drawHierarchy`. A presented sheet sits beside that view, so the picture shows the app and not the form |
| Recording | `SCRecordingOutput` to `.mp4`, 12 frames per second, cursor shown, `capturesAudio = false` | `RPScreenRecorder.shared()` with microphone and camera off, stopped with `stopRecording(withOutput:)` to `.mov` |
| Permission | `ensure()` checks `CGPreflightScreenCaptureAccess`, then asks with `CGRequestScreenCaptureAccess` | No preflight. `ensure()` returns `isAvailable`. Declining the system prompt becomes `CaptureError.permissionDenied` |

`Capture.swift` holds the shared parts:

- `CaptureError`, whose sentences name the platform through `PlatformWording`.
- `RecordingFrames.extract(from:count:)`: `AVAssetImageGenerator` pulls `count` PNG frames (default 6, at least 2), evenly spaced from 0.05 seconds in to 0.05 seconds before the end, long edge at most 1600 px. A recording always attaches the video, then its frames.
- `PickedMedia.attachments(data:type:)`: a photo or video from the library. Photos are re-encoded from their pixels so location and camera metadata are dropped. Videos get frames like a recording. Formats outside `AcceptedFormats` are refused.

`AcceptedFormats` accepts text and source files, images (`png`, `jpg`, `jpeg`, `heic`, `heif`, `gif`, `webp`, `tiff`, `bmp`), `pdf`, and video (`mov`, `mp4`, `m4v`). The full lists are in `Attachment.swift`.

## On-device check

`CompletenessReviewers.standard()` returns `OnDeviceCompletenessReviewer` where Foundation Models can be imported, and `NoReviewer` otherwise.

- `OnDeviceCompletenessReviewer` runs a `LanguageModelSession` with greedy sampling. The model answers in a `@Generable` `Verdict`: `readsAsComplete` and at most three questions, each with a `field`, `question` and `reason`.
- Questions decide the result: any question means `readsAsComplete` is `false`. Blank questions are dropped. An unknown field name falls back to `what-happened`.
- The check gives up after 20 seconds (`timeout`), or on any error, and the report goes as written with `source: .skipped`.
- `NoReviewer` returns `CompletenessReview.notReviewed`, with `source: .unavailable`, so a report says it was not reviewed.
- `availability()` reads `SystemLanguageModel.default.availability` without starting a session.

## Consent

`ConsentNotice.current` is versioned data (currently `2026-09-07.1`). `naming(_:)` replaces `$ORG` with `organizationName`. Acceptance is stored per version and per account through `ConsentStoring`. The default `UserDefaultsConsentStore` uses keys `beacon.consent.<accountID>`. Changing any wording means changing the version, and every reporter is asked again.

## The indexer

```bash
swift run beacon-index --source <dir> --output <file> [--app-name <name>] [--overrides <file>] [--commit <sha>] [--quiet]
```

`--output` defaults to `<source>/BeaconIndex.json`. The flags are documented in [the options reference](../docs/options.md).

How it builds the map:

1. **Build units.** The folders under `Sources/` when it exists, otherwise the top-level folders. Common build, dependency and test folders (including `Tests`) are ignored.
2. **Screens.** In each `.swift`, `.m` or `.mm` file: a `// beacon:screen Name` comment, or a type that conforms to `View`, `NSViewController`, `UIViewController`, `NSWindowController` or `Scene`. `// beacon:ignore` on the line skips it. Names are split from camel case with the `View`, `ViewController`, `WindowController`, `Screen` or `Scene` suffix dropped, so `ProjectSettingsView` reads "Project Settings".
3. **Overrides.** A JSON file with `areas` keyed by generated id (`name`, `blurb`, `hidden`, `absorbs`), `extraAreas`, and `ignore` (folder names). `absorbs` is applied first.
4. **Output.** `BeaconIndex.json` with `schemaVersion` 1, sorted by name.

`BeaconIndex.decode` refuses a map with a newer `schemaVersion`. `loadFromBundle(_:)` reads `BeaconIndex.json` from a bundle. `hiddenFromReporters` areas stay routable but are not offered on the picker. CI runs the indexer on this package and fails if the output file is empty.

## Seeding and reproduction

`BeaconSeed.applyIfRequested(into:)` replaces the host's data directory with a seed folder at launch. It acts only when `BEACON_SEED_ENABLE` is `1` and `BEACON_SEED_DIRECTORY` names an existing folder. Every outcome returns `Result {applied, explanation}`. `isReproductionRun()` is true when `BEACON_SEED_ENABLE` is `1`.

| Workflow | Trigger | Runner | What it does |
|---|---|---|---|
| `beacon-reproduce.yml` | `workflow_dispatch` with `issue` (required), `commit`, `seed` (default `default`) | `macos-26`, 30-minute limit | Checks out the commit, runs `swift build`, sets both seed variables to `Triage/seeds/<seed>`, then fails on purpose at the run step until it is pointed at the app's UI test scheme. Uploads `.xcresult` bundles and screenshots |
| `beacon-triage.yml` | Weekdays at 08:00 UTC, or `workflow_dispatch` with an optional `issue` | `ubuntu-latest`, 45-minute limit | Runs `anthropics/claude-code-action@v1` with `/beacon-triage`, using the `CLAUDE_CODE_OAUTH_TOKEN` secret |
| `ci.yml` | Push to `main`, pull requests | `macos-26`, 20-minute limit | `swift build`, `swift test`, and the indexer on this package |

`beacon-triage.yml` does not start `beacon-reproduce.yml`; each is run on its own. Runner facts and costs are in [CLOUD-REPRODUCTION.md](CLOUD-REPRODUCTION.md). `Scripts/beacon-adopt-github.sh` creates `Triage/seeds/` in the app repository.

## Operating the page

- **Republish** after any change to `Inbox/index.html`: call the Artifact tool with `file_path` set to the file and `url` set to the artifact. Omit `capabilities` so `db` and `artifact` carry forward, and omit `favicon` so it keeps its icon.
- **Add an app**: one `write_db` set on `apps/<id>` with `name`, `platform`, `repository`, `folder` and `tracker`. No republish is needed; both views read `apps` live.
- **Move an app off GitHub**: `write_db` update `apps/<id>` with `tracker: "board"`.
- **Create labels** on a repository: `Scripts/beacon-labels.sh <owner/repo>`, with `gh` signed in.
- **Give a tester access**: share the artifact with "Can edit" so the doorbell publishes. "Can interact" can send, and a scheduled pickup finds the report.
- **Inspect the store** from a session: `read_db` list `reports`, get `reports/<ref>`, or list `reports/<ref>/attachments` with an `out_dir`.

Before republishing, check the script parses, for example with `node -e "new Function(<script body>)"`. That check does not catch errors that happen at load, so open the page and send a report.

## Tests

Run the tests on the Mac:

```bash
swift test
```

Run the same suites on the iOS Simulator:

```bash
xcodebuild test -scheme Beacon-Package -destination 'platform=iOS Simulator,name=iPhone Air'
```

The source declares 94 tests in 22 suites. On the Mac, `swift test` runs 93: one test in `DiagnosticsTests` builds only for iOS. `LiveTransportTests` is skipped unless `BEACON_LIVE_GITHUB_REPO` and `BEACON_LIVE_GITHUB_TOKEN` are both set. It files a real issue, so close it afterwards.

| Target | Covers |
|---|---|
| `BeaconCoreTests` | Completeness rules, issue rendering, the secret sweep, accepted formats, consent, the app map, seeding, the inbox link, platform wording |
| `BeaconDiagnosticsTests` | The log ring, the folder scan (a known string written into a scanned file is asserted absent), the archive, the environment probe |
| `BeaconGitHubTests` | The four transports, GitHub's status codes as sentences, the relay size limit, and the live test |
| `BeaconIntelligenceTests` | Honest unavailability, the prompt's fields, and how a verdict becomes a review |
| `BeaconCaptureTests` | Frame offsets and extraction, picked photos and videos, metadata removal, refused formats, platform sentences |

`BeaconUI`, `Beacon` and the page have no automated tests. A change to the sheet is walked in `Examples/BeaconExample` on each platform it touches.

## Conventions

- Every documentation page has `*Last updated: YYYY-MM-DD*` under its title. Change the date when you change the page.
- Kinds, impacts, statuses and labels are defined once, in `IssueRenderer.Labels` and the page's `STATUS` map. A copy elsewhere needs a test that holds it equal.
- Deployment facts (the page URL, a repository, a folder, a branch) come from configuration or from the system, never from a literal at the point of use.
- Anything a reporter reads that names the device goes through `PlatformWording`.
- Platform differences live behind one shared name. Use `#if` in a view body only when a platform lacks the control, as in `exclusiveChoiceStyle()` and `FlowingButtons`.
- Build a change to `BeaconUI`, `BeaconCapture` or `BeaconDiagnostics` for the iOS Simulator as well as the Mac, because CI builds only on macOS:

```bash
xcodebuild build -scheme Beacon -destination 'generic/platform=iOS Simulator'
```

- On a release, bump the version in `plugin.json` and `marketplace.json` and the tag together.

## Decisions

**A bug cannot be filed without what was expected, what happened and the steps.** Only the reporter knows them, and they cannot be recovered later. The rule is deterministic, so it holds on every device with or without a model, and placeholder answers are refused too.

**The on-device check asks and never blocks.** It is a model's opinion about prose, so it asks at most three questions, once, never rewrites the reporter's words, and the reporter can always send.

**The check runs on the device or not at all.** A report is someone's unredacted description of their work, so it never goes to Private Cloud Compute or a server.

**Beacon reads about files, never inside them.** The folder scan lists names and sizes because the layout answers most questions. Files the reporter attaches are the only files read.

**Reports are not anonymous, and the reporter is told first.** A report that cannot be followed up is rarely fixed. The consent wording is versioned, and the version accepted is recorded on each report.

**The secret sweep runs last and shows what it found.** Running last means nothing is added after it. Silent scrubbing would hide a leak in the host app's logging.

**Only formats the triaging agent can read are accepted.** An attachment nobody can read adds nothing. A recording always carries still frames, because an agent cannot watch video.

**Only the host app is captured.** On macOS the capture asks only for this process's windows, and on iOS the screenshot is drawn from the app's own views. The reporter does not have to trust that nothing else is recorded.

**The app never sets severity.** The reporter says what it costs them. Severity is what it costs everyone, and that is triage's call.

**A report is saved to disk before it is sent.** The network is the one part nobody controls, so a failed send never loses a report.

**Attachments go to their own branch through the contents API.** The issue API cannot take a file, and the browser uploader is not a published endpoint. A separate branch means a report never touches a branch anyone builds from.

**The reproduction workflow fails until it is wired.** A half-configured workflow that passes would report a green run that proved nothing.
