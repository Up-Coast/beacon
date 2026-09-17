# Options

*Last updated: 2026-09-17*

Every setting Beacon reads, and where it is set.

| Where | What it sets |
|---|---|
| [`BeaconConfiguration`](#beaconconfiguration) | The app, the reporter, where the in-app sheet sends reports, and what it collects. Set once at launch. |
| [Transports](#transports) | Where a finished report from the in-app sheet goes. |
| [The in-app sheet](#the-in-app-sheet) | The report button, the sheet and the first-run walkthrough. |
| [The Beacon button](#the-beacon-button) | The button that opens your Beacon page, and the link it builds. |
| [The app list on the page](#the-app-list-on-the-page) | Which apps the Beacon page serves, and how each one is tracked. |
| [`beacon-index`](#beacon-index) | The app map behind the "which part of the app" picker. |
| [Platform permissions](#platform-permissions) | Info.plist keys and entitlements. |
| [The pickup](#the-pickup) | The pickup prompt and the two GitHub workflows. |

Everything below is available with `import Beacon`.

## `BeaconConfiguration`

Pass it to `Beacon.configure(_:gitHubAccount:audience:)` once at launch, before any view can show the sheet or build a Beacon page link. Calling it again replaces the configuration. Reading `Beacon.configuration` before the first call stops the app with a message. `Beacon.isConfigured` tells you whether it has been called.

| Argument | Type | Default | What it does |
|---|---|---|---|
| The configuration | `BeaconConfiguration` | required | The fields below. |
| `gitHubAccount` | `GitHubAccount?` | `nil` | With an account, the sheet offers GitHub sign-in to a tester who is not signed in. See [GitHub sign-in](#github-sign-in). |
| `audience` | `BeaconAudience` | `.everyone` | `.everyone` offers reporting in every build. `.testBuilds` offers it in builds run from Xcode and in TestFlight builds, and not in App Store builds. The build's channel comes from the App Store's own record of the install. |

`BeaconReportButton` draws nothing, and `.beaconWalkthroughOnFirstRun()` shows nothing, until `Beacon.isOffered` is true. With `.testBuilds` that takes a moment after launch.

| Field | Type | Default | What it does |
|---|---|---|---|
| `app` | `AppIdentity` | required | Which app and build this is. See [`AppIdentity`](#appidentity). |
| `organizationName` | `String` | required | Named in the privacy notice the tester accepts, as who can read the report. |
| `currentReporter` | `() -> Reporter?` | required | Who is signed in. Return `nil` when nobody is. The sheet then says so and files nothing. See [`Reporter`](#reporter). |
| `transport` | `any ReportTransport` | required | Where the in-app sheet sends reports. See [Transports](#transports). |
| `index` | `BeaconIndex?` | `nil` | The app map, usually `BeaconIndex.loadFromBundle(.main)`. With `nil`, the picker offers only "not sure" and "something new". |
| `settings` | `() -> [SettingEntry]` | `{ [] }` | Your app's settings, as you want them described on a report. See [`SettingEntry`](#settingentry). |
| `hostNotes` | `() -> [SettingEntry]` | `{ [] }` | Anything else to put on every report. |
| `fileTreeRoots` | `[FileTreeRoot]` | `[]` | Folders whose names and structure are listed on a report. Files are never opened. See [`FileTreeRoot`](#filetreeroot). |
| `hostSecrets` | `() -> [String]` | `{ [] }` | Values you know are secret. They are masked in the report text and in every text attachment. Read them from the keychain inside the closure. |
| `logTailLineCount` | `Int` | `400` | How many of the latest lines of `Beacon.log` go on a report. |
| `allowsScreenRecording` | `Bool` | `true` | Whether the sheet offers screen recording. With `false`, the record button and the walkthrough's mention of it are hidden. |
| `maximumRecordingSeconds` | `Int` | `180` | A recording stops by itself after this many seconds. |
| `consentStore` | `any ConsentStoring` | `UserDefaultsConsentStore()` | Where the tester's acceptance of the privacy notice is kept. |
| `reportArchiveDirectory` | `URL?` | see below | Where each report is saved on the device before it is sent. |

The default archive directory is `BeaconConfiguration.defaultArchiveDirectory(appName:)`: `Application Support/<app name>/Beacon/reports`, or `Application Support/Beacon/Beacon/reports` when the app name is empty. Each report is a folder named `<yyyy-MM-dd-HHmmss>-<reference>` holding `report.json`, `issue.md` and an `attachments` folder. `ReportArchive(directory:).saved()` lists the folders, newest first.

Settings, host notes, folders, the log, screenshots, recordings and secrets apply only to the in-app sheet. The Beacon page receives only what the link carries.

### `AppIdentity`

`AppIdentity(name:bundleIdentifier:version:build:commit:)`. Every argument defaults to empty.

| Field | Type | What it is |
|---|---|---|
| `name` | `String` | The app's name. It also names the default archive directory and matches the app on the Beacon page. |
| `bundleIdentifier` | `String` | The bundle identifier. |
| `version` | `String` | `CFBundleShortVersionString`. |
| `build` | `String` | `CFBundleVersion`. |
| `commit` | `String?` | The git commit the build was made from. Triage checks out this commit to reproduce a report. Write it into the build at build time. |

`AppIdentity.mainBundle(_:commit:)` fills the first four fields from a bundle, `.main` by default. It reads `CFBundleDisplayName`, falling back to `CFBundleName`, the bundle identifier, `CFBundleShortVersionString` and `CFBundleVersion`. Pass `commit` yourself.

```swift
app: AppIdentity.mainBundle(commit: BuildInfo.commit)
```

### `Reporter`

`Reporter(accountID:displayName:contact:)`.

| Field | Type | What it is |
|---|---|---|
| `accountID` | `String` | Your app's identifier for the person. Consent is remembered per account. |
| `displayName` | `String?` | The person's name. |
| `contact` | `String?` | How to reach them. |

### `SettingEntry`

`SettingEntry(name:value:isRedacted:)`. With `isRedacted: true`, the value is replaced by `set (not shown)`, so a report shows that the setting exists without showing it.

### `FileTreeRoot`

`FileTreeRoot(label:url:maximumDepth:maximumEntries:skippedDirectoryNames:)`.

| Field | Type | Default | What it does |
|---|---|---|---|
| `label` | `String` | required | What the folder is, in words a tester would use. |
| `url` | `URL` | required | The folder. |
| `maximumDepth` | `Int` | `4` | How many levels deep to list. |
| `maximumEntries` | `Int` | `800` | The most entries to list. The report says when the listing was cut short. |
| `skippedDirectoryNames` | `Set<String>` | `FileTreeRoot.defaultSkips` | Folder names that are not listed. |

`FileTreeRoot.defaultSkips` is `.git`, `.build`, `build`, `DerivedData`, `node_modules`, `.venv`, `venv`, `__pycache__`, `.next`, `dist`, `Pods`, `.gradle`, `.swiftpm`, `Carthage`, `.DS_Store` and `.cache`.

### `ConsentStoring`

Conform to `ConsentStoring` to keep consent in your own account store. It has two requirements: `record(for accountID: String) -> ConsentRecord?` and `save(_ record: ConsentRecord)`. The tester is asked again whenever the privacy notice's version changes.

`UserDefaultsConsentStore(defaults:keyPrefix:)` defaults to `UserDefaults.standard` and the key prefix `beacon.consent.`, followed by the account id.

### The log

Write to `Beacon.log` wherever the app does something worth knowing. The latest `logTailLineCount` lines go on each report from the in-app sheet.

```swift
let log = Beacon.log.category("sync")
log.info("started sync for \(projects.count) projects")
log.error("sync failed: \(error)")
```

| Member | What it does |
|---|---|
| `debug`, `info`, `notice`, `warning`, `error`, `fault` | Write one line at that level. On `Beacon.log` each takes `(_ message:, category:)`, and the category defaults to `app`. |
| `category(_:)` | Returns a logger that writes every line under one category. |
| `minimumLevel` | Lines below this level are dropped. Default `.info`. |

`Beacon.log` keeps the latest 2,000 lines in memory and also writes each line to the system log, under your bundle identifier as the subsystem.

## Transports

A transport is where the in-app sheet sends a finished report. Every report is saved to the archive directory first, so a failed send never loses it.

| Transport | What it does | Use it when |
|---|---|---|
| `SignedInGitHubIssueTransport` | Files an issue as whoever signed in to GitHub in the sheet. | Testers have GitHub accounts and sign in from inside the app. |
| `GitHubIssueTransport` | Files an issue with a GitHub token you hold. | Your app signs testers in itself. |
| `RelayTransport` | Posts the report to a service you run, which files the issue. | Testers have no GitHub accounts, and you will run a service. |
| `LocalBundleTransport` | Sends nothing. Tells the tester where the saved report is. | You collect reports by hand, or use only the Beacon page. |
| `FallbackTransport` | Tries one transport, then another if the first throws. | Pair GitHub with a local save, so a network failure still ends with a saved report. |

### `SignedInGitHubIssueTransport`

`SignedInGitHubIssueTransport(owner:repository:account:attachmentBranch:)`. `account` is the `GitHubAccount` you passed to `Beacon.configure`. The token is read from the keychain when a report is sent, so a tester who signs in mid-session can report at once. When GitHub answers 401, the sign-in is forgotten and the next report asks the tester to sign in again. It files the issue exactly as `GitHubIssueTransport` does.

### `GitHubIssueTransport`

`GitHubIssueTransport(client:attachmentBranch:)`.

| Argument | Default | What it does |
|---|---|---|
| `client` | required | A `GitHubClient`. |
| `attachmentBranch` | `beacon-attachments` | The branch attachments are committed to. It is created from the default branch the first time. |

Attachments are committed to `.beacon/attachments/<reference>/<filename>` on that branch, and the issue links to each one. Then the issue is created with its labels.

An account that can read the repository but not write to it can still file the report's words. GitHub refuses the attachments, and the issue says so and that the files stayed on the tester's device. GitHub also drops the labels silently, so give testers push access.

`GitHubClient(owner:repository:token:apiBase:)`. `apiBase` defaults to `https://api.github.com`.

### `RelayTransport`

`RelayTransport(endpoint:appToken:destinationName:)`.

| Argument | Default | What it does |
|---|---|---|
| `endpoint` | required | Your service's URL. |
| `appToken` | `nil` | Sent as `Authorization: Bearer <appToken>`, so your service can refuse other callers. It is not a GitHub credential. |
| `destinationName` | `the team` | Named on the sheet's review screen as where the report goes. |

The transport sends a `POST` with a JSON body:

```json
{
  "title": "…",
  "body": "…",
  "labels": ["beacon", "type:bug", "impact:slowed"],
  "reference": "…",
  "account": "<the reporter's accountID>",
  "attachments": [{"filename": "…", "base64": "…"}]
}
```

A `2xx` response may carry `issue_number` and `html_url`, which the tester is shown. Any other status is an error, and an `error` string in the response is shown to the tester. The transport refuses to send when the encoded attachments exceed 60 MB.

### `LocalBundleTransport`

`LocalBundleTransport(folderProvider:handoverInstruction:)`.

| Argument | Default | What it does |
|---|---|---|
| `folderProvider` | required | Returns the folder to show the tester. `{ ReportArchive(directory: <archive directory>).saved().first }` returns the report just saved. `{ nil }` shows no folder. |
| `handoverInstruction` | `Send the folder to the team and we'll take it from there.` | Shown to the tester after the report is saved. |

### `FallbackTransport`

`FallbackTransport(primary:fallback:onFallback:)`. When `primary` throws, `onFallback` is called with the error and `fallback` is used. The tester is told that GitHub could not be reached and the report was saved instead.

### Your own transport

Conform to `ReportTransport`:

```swift
public protocol ReportTransport: Sendable {
    var destinationDescription: String { get }
    func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt
}
```

`destinationDescription` is shown on the review screen. `ReportSubmission` holds the `report`, the rendered `issue` (title, body, labels) and the `attachments`, after secrets are masked. Return a `SubmissionReceipt(summary:issueNumber:url:isFiled:)`. Set `isFiled` to `false` when the report still needs someone to carry it the last step.

### GitHub sign-in

Pass a `GitHubAccount` to `Beacon.configure` and the sheet signs testers in for you. [Setup: the GitHub path](setup-github.md) step 4 shows the whole call.

`GitHubAccount(clientID:service:)`. `service` is the keychain service both items are kept under, and defaults to `beacon.github`.

| Member | What it does |
|---|---|
| `login` | The GitHub login of whoever is signed in, or `nil`. |
| `token` | That person's token, read from the keychain, or `nil`. |
| `reporter` | A `Reporter` built from the login, for `currentReporter`. |
| `connect(token:)` | Asks GitHub whose the token is and saves both. Returns the login. |
| `signOut()` | Forgets the login and the token. |
| `deviceFlow` | A `GitHubDeviceFlow` for this client id. |

To run the device flow yourself, use these directly.

| Call | What it does |
|---|---|
| `GitHubDeviceFlow(clientID:scopes:)` | `scopes` defaults to `["repo"]`. |
| `begin()` | Returns a `Challenge` with `userCode` and `verificationURL` to show the tester, plus `expiresAt`. |
| `awaitToken(_:)` | Waits until the tester enters the code, then returns the token. Throws `DeviceFlowError.declined`, `.expired` or `.failed`. |
| `GitHubTokenStore.save(_:account:service:)` | Saves the token in the keychain. Returns `true` on success. `service` defaults to `beacon.github`. |
| `GitHubTokenStore.read(account:service:)` | Returns the saved token, or `nil`. |
| `GitHubTokenStore.delete(account:service:)` | Removes the saved token. |

A `GitHubClient` holds the token it was created with. If you build one yourself, build the transport and call `Beacon.configure` again after a tester signs in.

## The in-app sheet

| API | What it does |
|---|---|
| `BeaconReportButton(title:)` | A button that opens the sheet. `title` is a `String` and defaults to `Report a problem`. It draws nothing when the audience does not include this build. |
| `.beaconReportSheet(isPresented:)` | Presents the sheet from your own button. |
| `.beaconWalkthroughOnFirstRun()` | Shows the walkthrough the first time the view appears for this person. Put it on your main view. |
| `.beaconWalkthroughSheet(isPresented:)` | Presents the walkthrough on demand, and marks it seen. |
| `Beacon.hasSeenWalkthrough(defaults:)` | Whether the walkthrough has been shown. Stored under the key `beacon.walkthrough.seen`. |
| `Beacon.markWalkthroughSeen(defaults:)` | Marks the walkthrough as shown. |
| `Beacon.isOffered` | Whether this build offers reporting, given the `audience` passed to `Beacon.configure`. |
| `Beacon.gitHubAccount` | The `GitHubAccount` passed to `Beacon.configure`, or `nil`. |

On a device where Apple Intelligence is available, the sheet reads the report on the device before sending and may ask up to three questions. There is no setting for it.

## The Beacon button

```swift
let inbox = BeaconInbox(page: URL(string: "<your Beacon page link>")!, repository: "your-org/harbour")
BeaconInboxButton(inbox, title: "Report a problem", area: "settings")
```

| API | What it does |
|---|---|
| `BeaconInbox(page:repository:)` | `page` is your Beacon page link. `repository` is the `owner/name` where fixes for this app are made. |
| `BeaconInboxButton(_:title:area:)` | Opens the page in the system browser, with the link filled in. `title` is a `LocalizedStringKey` and defaults to `Report a problem`. `area` prefills the part of the app, for a button on a specific screen. |
| `inbox.url(area:)` | Returns the link, to open some other way. Needs `Beacon.configure(_:)` first. |
| `inbox.url(for:environment:reporter:area:)` | Builds the link from values you pass, without the configuration. |

### Link query keys

The page reads these keys. A value that is empty is left out of the link.

| Key | Value |
|---|---|
| `app` | `AppIdentity.name`. The page selects the app whose document id or `name` matches, ignoring case. |
| `bundle` | `AppIdentity.bundleIdentifier` |
| `version` | `AppIdentity.version`. When present, the tester cannot change the selected app. |
| `build` | `AppIdentity.build` |
| `commit` | `AppIdentity.commit` |
| `repo` | `BeaconInbox.repository`. Used when the app's document has no `repository`. |
| `os` | Operating system name |
| `osVersion` | Operating system version |
| `device` | Device model |
| `arch` | CPU architecture |
| `locale` | Locale. The page falls back to the browser's language. |
| `tz` | Time zone. The page falls back to the browser's time zone. |
| `appearance` | Light or dark appearance |
| `textSize` | Text size setting |
| `reporter` | `Name <accountID>`, or `accountID` alone when there is no display name |
| `area` | The `area` argument |

Add `view=board` to your page link to open the board instead of the form.

## The app list on the page

The Beacon page reads its apps from the `apps` collection in the page's database. Each app is one document. Ask the Claude session that published the page to add or change a document. The page needs no republish.

| Field | Read by | What it is |
|---|---|---|
| Document id | Page, pickup | The app's short id, such as `harbour`. The link's `app` key can match it. Reports carry it as `app.id`. |
| `name` | Page | The name testers see in the app picker. The picker lists apps in `name` order. |
| `platform` | Page | `macOS` or `iOS`. Copied onto each report. |
| `repository` | Page, pickup | `owner/name` of the repository where issues are filed and fixes are made. |
| `folder` | Pickup | Where the app's source is, relative to the `CODE_ROOT` value in the pickup prompt. |
| `tracker` | Pickup | `github`: the pickup files each report as an issue and works the issue. `board`: the pickup works the report on the page, and the board is the whole tracker. |

The page itself needs the `db` and `artifact` capabilities when it is published. See [Setup: the Claude-only path](setup-claude-only.md) step 2.

## `beacon-index`

`beacon-index` reads your app's source and writes `BeaconIndex.json`, the app map behind the sheet's "which part of the app" picker. Run it from your app's repository:

```bash
swift run --package-path ~/beacon beacon-index --source . --output Harbour/Resources/BeaconIndex.json --app-name "Harbour" --commit "$(git rev-parse HEAD)"
```

Add the output to your app target as a resource. `BeaconIndex.loadFromBundle(.main)` loads `BeaconIndex.json` from the bundle, and returns `nil` when it is missing or unreadable.

| Flag | What it does | Default |
|---|---|---|
| `--source <dir>`, `-s` | The app's source folder. | The current folder |
| `--output <file>`, `-o` | Where to write the map. | `<source>/BeaconIndex.json` |
| `--app-name <name>` | The app name written into the map. | The source folder's name |
| `--overrides <file>` | A JSON file of hand edits, applied on every run. A path that does not exist is ignored. | None |
| `--commit <sha>` | The commit the map describes. | None |
| `--quiet`, `-q` | Prints only the summary line. | Off |
| `--help`, `-h` | Prints the flags. | |

An unknown flag exits with status 2. An overrides file that cannot be parsed, or an output that cannot be written, exits with status 1.

### How areas and screens are found

- **Areas.** Each folder under `Sources/` is an area when the source folder has one. Otherwise each top-level folder is an area.
- **Screens.** A `struct` or `class` whose declaration line conforms to `View`, `NSViewController`, `UIViewController`, `NSWindowController` or `Scene` is a screen. `ProjectSettingsView` is shown as "Project Settings".
- **Skipped folders.** `.git`, `.build`, `build`, `DerivedData`, `node_modules`, `.venv`, `Pods`, `Carthage`, `.swiftpm`, `vendor`, `third_party`, `Tests`, `tests`, `__pycache__`, `.next`, `dist` and `out`, plus hidden folders.

Two comments in your source change what is found:

```swift
// beacon:screen Project settings
struct PSView: View { … }

struct DebugProbeView: View { … } // beacon:ignore
```

- `// beacon:screen <name>` adds a screen with that name. The type on the next line is still found as well. Hide the extra one with `// beacon:ignore`.
- `// beacon:ignore` skips the line it is on. Put it on the declaration line itself.

### The overrides file

```json
{
  "areas": {
    "sync": {
      "name": "Sync",
      "blurb": "Anything about projects moving between machines.",
      "absorbs": ["sync-engine", "sync-models"]
    },
    "internals": { "hidden": true }
  },
  "extraAreas": [
    {
      "id": "onboarding",
      "name": "Getting started",
      "kind": "feature",
      "paths": ["Sources/App/Onboarding", "Sources/App/Welcome"],
      "screens": [],
      "hiddenFromReporters": false
    }
  ],
  "ignore": ["Generated"]
}
```

| Key | What it does |
|---|---|
| `areas.<id>.name` | Renames a found area. Area ids are the folder name in lowercase words joined by hyphens, such as `sync-engine` for `SyncEngine`. |
| `areas.<id>.blurb` | A sentence describing the area. |
| `areas.<id>.hidden` | `true` keeps the area out of the tester's picker. Triage can still route to it. |
| `areas.<id>.absorbs` | Area ids merged into this one, with their paths and screens. |
| `extraAreas` | Areas that have no folder of their own. Every entry needs all six keys shown above. `kind` is `module` or `feature`. |
| `ignore` | More folder names to skip. |

The area id becomes the `area:<id>` label on GitHub, so rename areas with `name`, not by renaming folders.

## Platform permissions

The Beacon button only opens a link, and needs nothing. The in-app sheet needs the following.

### macOS

| What | Why |
|---|---|
| `NSScreenCaptureUsageDescription` in Info.plist | Screenshots and recordings use ScreenCaptureKit. Apple's ScreenCaptureKit documentation asks apps to add this key. |
| Screen Recording permission | The tester grants it in System Settings. Beacon asks for it when the tester first takes a screenshot or records. If macOS has already asked, the sheet tells the tester where to turn it on. |
| **Outgoing Connections (Client)**, `com.apple.security.network.client` | Only for a sandboxed app, and only with `GitHubIssueTransport` or `RelayTransport`. |
| **User Selected File: Read Only**, `com.apple.security.files.user-selected.read-only` | Only for a sandboxed app, so testers can attach files. |

A sandboxed app can list folders in `fileTreeRoots` only where it has read access.

### iOS

No Info.plist keys are needed.

- **Recording** uses ReplayKit. iOS asks the tester to confirm when a recording starts, and asks again if more than eight minutes have passed since the last recording.
- **Photos** uses the system photo picker, which needs no photo library permission.
- **Screenshots** are drawn from the app's own views.

To remove recording on both platforms, set `allowsScreenRecording` to `false`.

## The pickup

### The pickup prompt

Set these in the `FILL IN` block at the top of [the pickup prompt](../Triage/PICKUP.md):

| Value | What it is |
|---|---|
| `BEACON_PAGE` | Your Beacon page link. |
| `BEACON_REPO` | The path to your Beacon checkout. The prompt reads the triage policy and skill from it. |
| `CODE_ROOT` | The folder that each app's `folder` is relative to. |
| `NOTIFY` | Where to report a run that filed or worked something: a chat channel through a connector, an email, or `nowhere`. |

How often it runs is up to you: a scheduled task, or a session you start. What triage may do on its own is set by [the triage policy](../Triage/TRIAGE.md). The prompt has a blank where you can relax gate 4 of that policy.

### `beacon-triage.yml`

| Setting | Value in the shipped file |
|---|---|
| Schedule | `0 8 * * 1-5`: 08:00 UTC, Monday to Friday |
| Manual run | From the Actions tab. The optional `issue` input triages one issue instead of the whole queue. |
| Runner and time limit | `ubuntu-latest`, 45 minutes |
| Concurrency | One run at a time. A new run waits for the current one. |
| Permissions | `contents: write`, `issues: write`, `pull-requests: write`, `id-token: write`, `actions: read` |
| Claude credential | The `CLAUDE_CODE_OAUTH_TOKEN` secret, passed as `claude_code_oauth_token`. Change it to `anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}` to use an API key. |
| Claude arguments | `--max-turns 120` and `--allowedTools "Bash,Read,Grep,Glob,Edit,Write,WebFetch"` |

The workflow also needs the Claude GitHub App installed on the repository. See [Setup: the GitHub path](setup-github.md) step 3.

### `beacon-reproduce.yml`

Started by hand only, from the Actions tab or `gh workflow run beacon-reproduce.yml`.

| Input | Required | What it is |
|---|---|---|
| `issue` | Yes | The issue being reproduced. |
| `commit` | No | The commit to check out, from the issue's metadata block. Defaults to the commit the run started from. |
| `seed` | No | A folder under `Triage/seeds/` to start the app with. Defaults to `default`. |

It runs on `macos-26` with a 30-minute limit, and uploads any `.xcresult` bundles and `Screenshots` folders. Replace its **Build** and **Run the reporter's steps** steps with your app's own. The second step fails until you do.

The step sets `BEACON_SEED_ENABLE=1` and `BEACON_SEED_DIRECTORY` to the seed folder. To start your app with that data, call `BeaconSeed.applyIfRequested(into:)` at launch with your app's data directory. It replaces the directory only when both variables are set. `BeaconSeed.isReproductionRun()` tells your app to skip onboarding and sign-in during a run.
