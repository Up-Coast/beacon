# Quickstart

*Last updated: 2026-09-07*

Fifteen minutes from an app with no feedback button to reports arriving.

## Before you start

Pick a path and do its setup once: [the Claude-only path](setup-claude-only.md) or
[the GitHub path](setup-github.md). Both give you the one thing this page needs, the link
to your Beacon page (`https://claude.ai/code/artifact/…`). Every app you own shares the
same page — the app tells the page which one it is. On the GitHub path without the board,
skip step 3 and put the in-app sheet in instead (its setup page, step 4).

## 1. Add the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Up-Coast/beacon.git", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "Beacon", package: "beacon")]),
]
```

In Xcode: **File › Add Package Dependencies…**, paste the same URL, and add the `Beacon`
product to your app target.

## 2. Tell Beacon about your app

Once, at launch. Everything Beacon needs to know arrives here and nowhere else.

```swift
import Beacon

@main struct HarbourApp: App {
    init() {
        Beacon.configure(BeaconConfiguration(
            app: AppIdentity(
                name: "Harbour",
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
                commit: BuildInfo.commit),          // bake this in at build time
            organizationName: "the Harbour team",
            currentReporter: {
                guard let account = Account.signedIn else { return nil }
                return Reporter(accountID: account.email, displayName: account.name)
            },
            transport: LocalBundleTransport(folderProvider: { nil })))
    }

    var body: some Scene { WindowGroup { ContentView() } }
}
```

Two of these deserve a sentence:

- **`commit`** is what lets Claude check out the exact code the tester was running. Put
  the git commit into the build (a build phase that writes it to a generated file is the
  usual way). Without it, reproduction falls back to the version and build number.
- **`currentReporter`** returns who is signed in, or `nil`. Reports are not anonymous:
  a report nobody can follow up on cannot be acted on. Beacon says so to the tester rather
  than filing one.

The `transport` line is where the in-app sheet sends reports on the GitHub path; on the
Claude-only path it can stay as shown.

## 3. Put the button in

Give Beacon the page link and where reports for this app should go, then place the button
wherever your testers will find it.

```swift
let beacon = BeaconInbox(
    page: URL(string: "https://claude.ai/code/artifact/…")!,   // your Beacon page
    repository: "your-org/harbour")                              // where fixes are made

// Anywhere in your views — a toolbar, a menu, a settings screen:
BeaconInboxButton(beacon)
```

On macOS a good place is the Help menu; on iOS, the settings screen. The button opens the
Beacon page in the browser with the app, version, build, commit, OS, device and signed-in
tester already in the link. The tester writes only what they know.

Keep the page link and the repository name in your app's configuration, not in the view
that shows the button, so there is one place to change them.

## 4. Run it

Build, press the button, send a test report. It appears on your board within a few
seconds (see [The board](the-board.md)), and, on the GitHub path, as an issue at the
next pickup.

## Next

- [How it works](how-it-works.md) — what happens after send
- [For testers](for-testers.md) — the page to hand to the people testing your app
- [Options](options.md) — what else you can pass in
