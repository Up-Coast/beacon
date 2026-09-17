# Quickstart

*Last updated: 2026-09-17*

Put a Beacon report button in your app and send a test report.

## Before you start

Set up a path first: [Claude-only](setup-claude-only.md) or [GitHub](setup-github.md). Keep the link to your Beacon page. One page serves all your apps, because the button tells the page which app is reporting.

On the GitHub path without the page, do steps 1 and 2 here, then put the in-app sheet in instead of step 3 ([Setup: the GitHub path](setup-github.md), step 4).

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

In Xcode, choose **File > Add Package Dependency**, enter the same URL, and add the `Beacon` product to your app target.

## 2. Configure Beacon at launch

Call `Beacon.configure` once, before any view can show a report button.

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
                commit: BuildInfo.commit),
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

`BuildInfo` and `Account` stand for your own code.

| Field | What to pass |
|---|---|
| `app` | Your app's name, bundle identifier, version and build. `commit` is the git commit the build was made from, written into the build at build time. It lets triage check out the exact code the tester ran. |
| `organizationName` | Who reads reports. The privacy notice names it. |
| `currentReporter` | The signed-in person, or `nil`. The in-app sheet will not file a report without a reporter. |
| `transport` | Where the in-app sheet sends reports. On the Claude-only path, keep `LocalBundleTransport` as shown. On the GitHub path, see [Setup: the GitHub path](setup-github.md). |

Every other field is optional. See [Options](options.md).

## 3. Put the button in

1. Describe your Beacon page once, in your app's configuration code:

   ```swift
   let inbox = BeaconInbox(
       page: URL(string: "<your Beacon page link>")!,
       repository: "your-org/harbour")
   ```

   `repository` is the `owner/name` of the repository where fixes for this app are made.

2. Place the button in a view testers will find, such as the Help menu on macOS or a settings screen on iOS:

   ```swift
   BeaconInboxButton(inbox)
   ```

The button opens your Beacon page in the browser. The link already carries the app, version, build, commit, operating system, device and signed-in tester, so the tester writes only what they saw.

## 4. Send a test report

1. Build and run the app.
2. Press **Report a problem** and send a report.
3. Open [the board](the-board.md) and find the report.

## Next

- [For testers](for-testers.md): the page to send the people testing your app.
- [How it works](how-it-works.md): what happens after send.
- [Options](options.md): every field you can set.
