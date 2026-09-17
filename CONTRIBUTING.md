# Contributing

*Last updated: 2026-09-17*

Beacon is a Swift package, a page (`Inbox/index.html`), a triage policy and the skills that run it. Read the [developer guide](internal/DEVELOPER-GUIDE.md) before changing any of them.

## Set up

1. Install Xcode with the macOS 26 and iOS 26 SDKs.
2. Clone the repository:

   ```bash
   git clone https://github.com/Up-Coast/beacon.git
   cd beacon
   ```

3. Run the tests on the Mac:

   ```bash
   swift test
   ```

4. Run the same tests on the iOS Simulator. Use any simulator you have installed.

   ```bash
   xcodebuild test -scheme Beacon-Package -destination 'platform=iOS Simulator,name=iPhone Air'
   ```

To try the in-app sheet, run the [example app](Examples/BeaconExample/README.md).

## Where things live

| To change | Edit | Also |
|---|---|---|
| The completeness rules | `Sources/BeaconCore/Completeness.swift` | Copy the change into `Inbox/index.html`. No test checks that the two match. |
| The query keys the page reads | `BeaconInbox.Key` in `Sources/BeaconCore/InboxLink.swift` | Change `Inbox/index.html` and the key list in `Tests/BeaconCoreTests/InboxLinkTests.swift`. |
| Label names | `IssueRenderer.Labels` in `Sources/BeaconCore/IssueRendering.swift` | Change `Scripts/beacon-labels.sh` and the status map in `Inbox/index.html` to match. |
| The page | `Inbox/index.html` | Republish it. Never edit a published copy by hand. |
| The triage policy | `Triage/TRIAGE.md` | Check `.claude/skills/beacon-triage/SKILL.md` still says how to apply it. The policy wins where they differ. |
| Which module may import which | `Package.swift` | Each target imports only the targets listed as its dependencies. |

## Pull requests

- One change per pull request. The subject line says what changed, in words, in under 100 characters.
- Every behaviour change includes a test.
- A change to what the reporter sees includes a run of the example app on each platform it touches.
- CI runs `swift build`, `swift test` and the indexer on this package, on a macOS runner. It must pass.
- Every documentation page has a `*Last updated: YYYY-MM-DD*` line directly under its title. Change the date when you change the page.
- Each fact in the documentation lives on one page. Other pages link to it.

## Report a problem

Open an issue on GitHub. From inside an app that uses Beacon, use the app's report button instead.
