# What is collected

*Last updated: 2026-09-17*

A report reaches your team one of two ways: the Beacon page, a web page the app opens with a link, or the in-app sheet that the GitHub setup adds. This page lists what each one carries, what neither collects, and where a report goes. Use it to tell your testers what a report contains.

## At a glance

| What | Beacon page | In-app sheet |
|---|---|---|
| App name, version, build and commit | Yes, from the link | Yes |
| Operating system and version, device model, processor type | Yes, from the link | Yes |
| Language and time zone | Yes, from the link, or the browser's own when the link has none | Yes |
| Appearance (light or dark) and text size | Yes, from the link | Yes. Text size on iPhone and iPad only |
| The browser's user agent | Yes | No |
| Memory, free disk space, reduced motion, whether Apple's on-device model can run | No | Yes |
| Who is reporting | What the tester types in **Who you are**, filled in from the link when the app knows | The account the app has signed in |
| What the tester writes and picks | Yes | Yes |
| Images | Up to 6, shrunk on the tester's device | Screenshots, and pictures from Photos on iPhone and iPad |
| Screen recordings | No | Yes, with still frames taken from them |
| Other files | No | Text, PDF, image and video files |
| The app's settings | No | Yes, as the app describes them |
| The app's log | No | The last 400 lines, by default |
| Names and sizes of files in folders the app names | No | Yes. Never their contents |
| The version of the privacy notice the tester accepted | No | Yes |
| A sweep that masks passwords and keys before sending | No | Yes |

## The Beacon page

### What the link carries

The app builds the link with `BeaconInbox` or `BeaconInboxButton`. It holds the app's name, bundle identifier, version, build, commit and repository; the operating system and version, device model, processor type, language, time zone, appearance and text size; who is signed in; and, optionally, the part of the app. Empty values are left out. The query keys are listed in [Options](options.md).

The page adds the browser's user agent to every report. When the link has no language or time zone, the page uses the browser's.

### What the tester adds

- Which app, when the link does not name one the page knows.
- **Who you are**: a name or email. Required.
- The kind of report, and its answers. A bug needs what happened, what they expected, the steps and whether it happens again. A feature request needs what they want and, optionally, why. Feedback needs a message.
- **Which part of the app**, in their own words. Optional.
- **How much this affects you**.
- Images.

### Images

- Up to 6 per report. Only image files are accepted. On a Mac, a tester can also paste an image into the page.
- Each image is redrawn on the tester's device as a JPEG, at most 1600 pixels on its longest side and at most 180 KB. The original file is never uploaded.
- An image that cannot get under 180 KB is refused with a message.

### Where a page report goes

1. The report is saved to the page's shared store as `reports/<reference>`, with each image as its own record under it.
2. The page publishes a new version of its `data/doorbell.json` file holding the reference and the time. This wakes a Claude session that is watching the page.
3. The pickup (`Triage/PICKUP.md`) reads new reports. For an app whose `tracker` is `github`, it files a GitHub issue and commits the images to the repository's `beacon-attachments` branch under `.beacon/attachments/<reference>/`. For an app whose `tracker` is `board`, the report is worked on the page and stays there.

The page only works for someone signed in to Claude as a member of the organization that owns it. Anyone who can open the page can open its board (`?view=board`), which lists every report with its words and images.

## The in-app sheet

### Collected automatically

The sheet collects these when the tester presses **Next** on the form, so the review screen shows real values.

| What | Detail | Enforced in |
|---|---|---|
| App | Name, bundle identifier, version, build and commit, from `BeaconConfiguration.app` | `Configuration.swift` |
| System | Operating system and version, hardware model (for example `Mac15,3` or `iPhone17,1`), processor architecture, language, time zone | `EnvironmentProbe.swift` |
| Display | Appearance, text size (iPhone and iPad only), reduced motion | `EnvironmentProbe.swift` |
| Machine | Memory and free disk space | `EnvironmentProbe.swift` |
| On-device model | Whether Apple's on-device model can run, and if not, why. Reading this starts no model | `EnvironmentProbe.swift` |
| Settings | Whatever the app returns from `settings`. An entry made with `isRedacted: true` is recorded as `set (not shown)` | `ReportContext.swift` |
| From the app | Whatever the app returns from `hostNotes` | `ReportContext.swift` |
| Log | The last `logTailLineCount` lines (default 400) of `BeaconLog`. The log keeps 2000 lines in memory, at level `info` and above by default | `BeaconLog.swift` |
| Folder layout | See the next section | `FileTreeScanner.swift` |

`BeaconLog` also writes every line to the system log, marked public, so it shows in Console. It writes nothing to disk.

### Folder layout

- Only folders the app lists in `fileTreeRoots` are listed. Nothing else is discovered.
- For each entry Beacon records its path inside the folder, whether it is a folder, its size in bytes and its modification date.
- Beacon never opens a file. The scanner calls only `contentsOfDirectory` and `resourceValues`. The test `itRecordsNamesAndSizesAndNeverContents` writes a file with known contents and checks they appear nowhere in the result.
- The walk stops at 4 levels deep and 800 entries by default, and says when it stopped.
- Build and package folders are marked `(skipped)` and not walked: `.git`, `.build`, `build`, `DerivedData`, `node_modules`, `.venv`, `venv`, `__pycache__`, `.next`, `dist`, `Pods`, `.gradle`, `.swiftpm`, `Carthage`, `.DS_Store`, `.cache`.
- The folder's own path has the home folder replaced with `~`, so `/Users/sam/Projects` becomes `~/Projects`.

### Screenshots and recordings

| | Mac | iPhone and iPad |
|---|---|---|
| **Take a screenshot** | The app's largest on-screen window, captured with a ScreenCaptureKit filter for that window only. The cursor is included | Drawn from the app's own views, not read from the display. The report sheet is left out |
| **Record what happens** | The same window, at 12 frames a second, with no audio | ReplayKit, which records inside the app only. The microphone and camera are switched off |
| Permission | macOS asks for screen recording permission once. After a refusal, the app tells the tester where to switch it on in System Settings | iOS asks the tester to confirm before recording |
| Length | Stops by itself at `maximumRecordingSeconds` (default 180) | Same |

- `allowsScreenRecording: false` removes the recording button.
- Every recording is attached with 6 still frames taken from it, evenly spaced, at most 1600 pixels on the longest side, so triage can see what it cannot play.
- A recording is written to a temporary file while it runs, and the file is removed once it is attached.

### Photos and files

- **Choose from Photos** (iPhone and iPad): a picture is re-encoded from its pixels, so its location, camera and time details are dropped. A video is attached as it is, with 6 still frames.
- **Add a file**: text and source files, images, PDFs and `mov`, `mp4` or `m4v` videos. Any other file type is refused with a message. The full list is `AcceptedFormats` in `Attachment.swift`.
- One file may be at most 25 MB. A report's attachments may total at most 60 MB.

### The on-device check

1. When Apple's on-device model can run, the send button reads **Check and send**. Otherwise it reads **Send**, and the review screen says why no check will run.
2. On **Check and send**, the model reads the report on the device. Beacon uses `SystemLanguageModel.default` only and has no code for Private Cloud Compute or any server model.
3. If the model has questions, the tester sees at most 3 of them. Answers are added to the report. Nothing the tester wrote is changed.
4. **Send it** sends the report, whether or not any question was answered.

A few things to know:

- The check gives up after 20 seconds and the report goes as written.
- The questions asked appear in the issue under "Checked before sending".
- The issue's metadata block records `review_source`: `on-device` when the model read it, `skipped` when it timed out or failed. When the model cannot run, no check happens and no `review_source` is written.

### The secret sweep

The sweep runs at send, after the on-device check. It covers the finished issue text, which holds the tester's words, settings, log and folder layout, and every attached file with a text extension. Images, videos and PDFs are not swept.

It masks each match with `[removed by Beacon]`:

- Anthropic, OpenAI-style, Google, Stripe and AWS keys
- GitHub and Slack tokens
- Private key blocks, bearer tokens and JSON web tokens
- Settings written like `password=` or `api_key:` followed by a value
- URLs with a password in them
- Every value of 8 characters or more that the app returns from `hostSecrets`

After sending, the sheet lists what was removed and where, never the value. The **Everything being sent** preview on the review screen shows the text before the sweep.

### Consent

- Before a tester's first report, the sheet shows a notice. It says the report is not anonymous, the team may come back to them, the report becomes a GitHub issue that only `organizationName` can read, what is collected, that file names are listed but never opened, and that attachments are read.
- The notice has a version, currently `2026-09-07.1`. Acceptance is kept per account, in `UserDefaults` under `beacon.consent.<account>` unless the app sets `consentStore`.
- When the wording changes, the version changes and every tester is asked again.
- Each report records the accepted version as `consent_version` in its metadata block.
- When no one is signed in, the sheet stops at "You'll need to be signed in first".

### The saved copy

After the sweep and before sending, the sheet saves the report on the device. A failed send never loses it, and the tester is told where it is.

| File | What |
|---|---|
| `report.json` | The whole report, without attachment bytes |
| `issue.md` | The issue title, labels and body |
| `attachments/` | Every attachment, after the sweep |

The folder is `<Application Support>/<app name>/Beacon/reports/<date-time>-<reference>/`. Set `reportArchiveDirectory` to change it. `report.json` holds some items the issue does not show: the bundle identifier, reduced motion and file modification dates.

### Where a sheet report goes

Only to the transport the app configures. The transports and their settings are in [Options](options.md).

| Transport | Where the report goes |
|---|---|
| `GitHubIssueTransport` | An issue on the repository, filed under the tester's own GitHub account. Attachments are committed to the `beacon-attachments` branch under `.beacon/attachments/<reference>/` and linked from the issue |
| `RelayTransport` | Your endpoint receives the title, body, labels, reference, account and attachments, and files the issue |
| `LocalBundleTransport` | Nowhere. The saved copy stays on the device for the tester to hand over |
| `FallbackTransport` | The first transport, or the second when the first fails |

Beacon makes network calls only to send through the transport and, for `GitHubIssueTransport`, to sign the tester in to GitHub.

## Never collected

- **File contents** from folders the app names. Only files the tester attaches are read.
- **Anything outside those folders.**
- **Other apps, the desktop, or anything behind the app** in a screenshot or recording.
- **Audio**, and on iPhone and iPad, **the camera**.
- **Logs, settings or folder layout** from the Beacon page. The page reads only the link, what the tester types and the images they choose.

## How long reports are kept

Beacon deletes nothing.

- **Page reports** stay in the page's store, and the images committed for GitHub apps stay on the `beacon-attachments` branch.
- **Sheet reports** stay in the saved copy on the tester's device until someone deletes it. The issue and the `beacon-attachments` branch follow the repository's own rules.
- **Consent records** stay in the app's `UserDefaults`, or in the app's `consentStore`.
