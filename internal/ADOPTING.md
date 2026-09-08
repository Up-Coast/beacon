# Putting Beacon in an app

*Internal, long-form. The public setup pages are `docs/setup-claude-only.md`
and `docs/setup-github.md`; this is the full walkthrough of the native
sheet's configuration with every piece you can swap.*

Everything here is one file's worth of work in the host app, plus one line
in the build. If it's taking longer than that, something is wrong with
Beacon rather than with the app.

## 1. Depend on it

```swift
dependencies: [
    .package(url: "https://github.com/Up-Coast/beacon.git", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "Beacon", package: "beacon")]),
]
```

## 2. Decide how reports reach GitHub

This is the only real decision. Three answers ship; pick by who your
testers are.

### Everyone reporting has a GitHub account with access to the repo

Direct. No server, no secret in the app. The reporter signs in once with
GitHub's device flow and reports post under their own account.

```swift
let flow = GitHubDeviceFlow(clientID: "Iv1.your-oauth-app-client-id")
let challenge = try await flow.begin()
// Show challenge.userCode, open challenge.verificationURL
let token = try await flow.awaitToken(challenge)
GitHubTokenStore.save(token, account: reporter.accountID)
```

The client id is public by design — there is no client secret, and nothing
worth extracting from the binary. Ask for the `repo` scope and nothing else.

```swift
transport: GitHubIssueTransport(
    client: GitHubClient(owner: "your-org", repository: "harbour", token: token))
```

### Your testers are inside your Claude organisation

Open the shared inbox page instead of the native sheet. No server, no
GitHub accounts, and the report is picked up by a Claude session that
watches the page. The trade: testers must be signed in to Claude as
members of your organisation, and nothing beyond the link's query string
comes along. Details in `Inbox/README.md`.

```swift
let inbox = BeaconInbox(page: Deployment.inboxPage, repository: "your-org/harbour")
BeaconInboxButton(inbox)   // opens the page in the browser, prefilled
```

### Your testers don't have GitHub accounts

Run a small endpoint that holds the credential and files for everyone.

```swift
transport: RelayTransport(
    endpoint: URL(string: "https://reports.example.com/beacon")!,
    appToken: BuildSecrets.relayToken,
    destinationName: "the Harbour team")
```

The relay takes `{title, body, labels, reference, account, attachments[]}`
and answers `{issue_number, html_url}`. `appToken` is a shared value the
relay checks so it isn't an open issue-filing hole; it is **not** a GitHub
credential and can't file anything on its own. That distinction is why it
is safe to ship it inside the app and a GitHub token is not.

### Neither, or not yet

Save it and hand it over. Works today, needs nothing.

```swift
transport: LocalBundleTransport(folderProvider: { lastSavedReportFolder })
```

### Recommended: chain them

```swift
transport: FallbackTransport(
    primary: GitHubIssueTransport(client: client),
    fallback: LocalBundleTransport(folderProvider: { lastSavedReportFolder }),
    onFallback: { Beacon.log.error("GitHub was unreachable: \($0)") })
```

Nobody loses a report because a network was down.

## 3. Configure

```swift
import Beacon

@main struct HarbourApp: App {
    init() { configureBeacon() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .beaconWalkthroughOnFirstRun()
        }
        .commands {
            CommandGroup(after: .help) { BeaconReportButton() }
        }
    }
}

func configureBeacon() {
    Beacon.configure(BeaconConfiguration(
        app: AppIdentity(
            name: "Harbour",
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            // Bake this in at build time. Without it, triage cannot check
            // out the exact code the reporter was running.
            commit: BuildInfo.commit),

        organizationName: "the Harbour team",

        // Return nil when nobody is signed in — Beacon then says so and
        // stops, rather than filing a report nobody can follow up on.
        currentReporter: {
            guard let account = Account.signedIn else { return nil }
            return Reporter(accountID: account.email, displayName: account.name)
        },

        transport: transport,

        // Generated in step 4.
        index: BeaconIndex.loadFromBundle(.main),

        // Anything secret goes in with isRedacted: true rather than being
        // left out — knowing a key is set is often the whole answer.
        settings: {
            [SettingEntry(name: "Theme", value: Settings.theme.rawValue),
             SettingEntry(name: "Sync", value: Settings.syncEnabled ? "on" : "off"),
             SettingEntry(name: "API key", value: "", isRedacted: Settings.hasKey)]
        },

        // Names and structure only; nothing is ever opened.
        fileTreeRoots: [
            FileTreeRoot(label: "Your projects", url: Paths.projectsDirectory),
        ],

        // Read from the keychain at call time, for the final sweep.
        hostSecrets: { [Keychain.apiKey, Keychain.syncToken].compactMap { $0 } }))
}
```

Then write to the log wherever the app does anything worth knowing about.
The last few hundred lines ride on every report automatically.

```swift
let log = Beacon.log.category("sync")
log.info("started sync for \(projects.count) projects")
log.error("sync failed: \(error)")
```

## 4. Index the app in your build

```bash
swift run beacon-index \
    --source . \
    --output Sources/YourApp/Resources/BeaconIndex.json \
    --app-name "Harbour" \
    --commit "$(git rev-parse HEAD)" \
    --overrides Triage/beacon-index-overrides.json
```

Bundle the output as a resource. The indexer finds build units and the
screens inside them; generated output is never hand-edited, so anything a
person wants to say goes in the overrides file and is re-applied on every
run:

```json
{
  "areas": {
    "beacon-git-hub": { "name": "GitHub" },
    "internals": { "hidden": true },
    "sync": {
      "name": "Sync",
      "blurb": "Anything about projects moving between machines.",
      "absorbs": ["sync-engine", "sync-models"]
    }
  },
  "extraAreas": [
    { "id": "onboarding", "name": "Getting started", "kind": "feature",
      "paths": ["Sources/App/Onboarding", "Sources/App/Welcome"] }
  ],
  "ignore": ["Generated"]
}
```

You can also mark a screen in source, which beats every guess the indexer
makes:

```swift
// beacon:screen Project settings
struct PSView: View { ... }

// beacon:ignore
struct DebugProbeView: View { ... }
```

## 5. Set the repository up, once

```bash
./Scripts/beacon-labels.sh your-org/harbour
cp -R Triage .claude/skills/beacon-triage <app repo>/
cp .github/ISSUE_TEMPLATE/*.yml <app repo>/.github/ISSUE_TEMPLATE/
cp .github/workflows/beacon-triage.yml <app repo>/.github/workflows/
```

Then wire the scheduled triage: see the comments at the top of
`beacon-triage.yml`, and [CLOUD-REPRODUCTION.md](CLOUD-REPRODUCTION.md) for
running the verification leg off your own machine.

## 6. Permissions, on each platform

**macOS.** Screen capture needs the Screen Recording permission, granted in
System Settings the first time somebody records. Beacon asks for it at the
moment they press record, and explains the Settings path if macOS has
already been asked once. The file importer handles its own access, sandbox
or not. No `Info.plist` usage string is needed.

**iOS.** Nothing to add to `Info.plist`. ReplayKit shows its own permission
sheet when a recording starts (and again in a later session), the Photos
picker runs out of process and needs no photo-library permission, and the
screenshot is drawn from the app's own views. Recording needs a physical
device to produce a video; the simulator's recorder starts but hands back
nothing.

To switch recording off entirely — right for an app that shows other
people's private data — set `allowsScreenRecording: false`. The button
disappears and the walkthrough stops mentioning it.

## 7. Walking it before you ship it

`Examples/BeaconExample` is the smallest host app: two rows to report about, the report
button, the walkthrough on first run, reports saved locally. It builds for iPhone, iPad and
Mac from one xcodegen spec and is how the sheet is checked on screen; its README has the
commands. Walk your own app the same way — consent, each kind of report, a screenshot, a
recording, review, send — on every platform you ship before the first tester sees it.

## Swapping pieces out

Every collaborator is a protocol with a shipped default:

| Seam | Default | Swap it when |
|---|---|---|
| `ReportTransport` | — (required) | always: it's the one real decision |
| `ConsentStoring` | `UserDefaultsConsentStore` | the app has its own account store |
| `CompletenessReviewing` | on-device, else none | you want a different reviewer, or none |
| `BeaconLog` | `.shared` | you want a separate ring for a subsystem |
| `BeaconIndex` | bundled JSON | you'd rather build the areas in code |
