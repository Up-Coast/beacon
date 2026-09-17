# Beacon

*Last updated: 2026-09-17*

Beacon is bug, feature-request and feedback reporting for macOS 26 and iOS 26 apps. A tester presses a button in your app, and the report arrives with the app version, build, device and, from the in-app sheet, the app's log, screenshots and a screen recording. A Claude session then works each report by a written triage policy: it reproduces it, fixes what is small, and explains the rest.

Documentation site: [up-coast.github.io/beacon](https://up-coast.github.io/beacon/)

## Install

1. In Claude Code, add the marketplace and install the plugin:

   ```text
   /plugin marketplace add Up-Coast/beacon
   /plugin install beacon@up-coast
   ```

2. Ask Claude to "set up Beacon in my app".

The plugin adds two skills: `beacon-setup` puts Beacon into your app and sets up the pickup, and `beacon-triage` works the reports. It carries the whole repository, so nothing else needs cloning.

To add the Swift package yourself, or work from a clone, see [Getting Beacon](docs/README.md#getting-beacon).

## Adopt it

Adopting Beacon is three things: configure it once at launch, put a button in a view, and run the indexer in your build.

```swift
import Beacon

Beacon.configure(BeaconConfiguration(
    app: AppIdentity.mainBundle(),
    organizationName: "the Harbour team",
    currentReporter: { Reporter(accountID: "tester@example.com") },
    transport: LocalBundleTransport(folderProvider: { nil })))
```

```swift
BeaconReportButton()
```

```bash
swift run beacon-index --source . --output Resources/BeaconIndex.json --app-name Harbour
```

The [Quickstart](docs/quickstart.md) has the full steps. The two setup paths, Claude-only and GitHub, are compared in the [documentation index](docs/README.md#two-setup-paths).

## What is in this repository

| Path | What it is |
|---|---|
| `Sources/` | The Swift package: `BeaconCore`, `BeaconDiagnostics`, `BeaconIntelligence`, `BeaconCapture`, `BeaconGitHub`, `BeaconUI`, the `Beacon` library your app imports, and the `beacon-index` command-line tool. |
| `Tests/` | The package's tests. |
| `Inbox/` | The Beacon page: a Claude artifact testers report through, with the board. See [Inbox/README.md](Inbox/README.md). |
| `Triage/` | The triage policy and the pickup prompt. |
| `Scripts/` | `beacon-adopt-github.sh`, which puts the GitHub pieces into an app's repository, and `beacon-labels.sh`, which creates the labels. |
| `.claude/skills/` | The `beacon-setup` and `beacon-triage` skills. |
| `.claude-plugin/` | The plugin manifest and marketplace entry. |
| `.github/` | Beacon's CI, the triage and reproduce workflow templates, and the issue templates. |
| `Examples/BeaconExample/` | A small app to try the in-app sheet on iPhone, iPad and Mac. See [its README](Examples/BeaconExample/README.md). |
| `docs/` | The documentation for people adding Beacon to an app. |
| `internal/` | The documentation for people changing Beacon. |

## Read more

| Page | Read it when |
|---|---|
| [Quickstart](docs/quickstart.md) | You want the button in your app now. |
| [Setup: the Claude-only path](docs/setup-claude-only.md) | You have a Claude organization and do not use GitHub. |
| [Setup: the GitHub path](docs/setup-github.md) | You track work in GitHub and want issues and the in-app sheet. |
| [How it works](docs/how-it-works.md) | You want to know what happens after a tester presses send. |
| [The board](docs/the-board.md) | You want to see every report and its outcome. |
| [What happens to a report](docs/what-happens-to-a-report.md) | You want to know what Claude does with a report, and what it never does. |
| [What is collected](docs/what-is-collected.md) | You need to tell testers what a report contains. |
| [Options](docs/options.md) | You want every configuration field, transport and flag. |
| [For testers](docs/for-testers.md) | You want the page to send to your testers. |
| [FAQ](docs/faq.md) | You want short answers to common questions. |
| [Triage policy](Triage/TRIAGE.md) | You want the full rules the triage follows. |
| [Pickup prompt](Triage/PICKUP.md) | You are setting up the session that picks reports up. |
| [Developer guide](internal/DEVELOPER-GUIDE.md) | You are changing Beacon itself. |
| [Status](internal/STATUS.md) | You want to know what is proven and what is not yet. |
| [Cloud reproduction](internal/CLOUD-REPRODUCTION.md) | You want to reproduce reports on GitHub-hosted macOS runners. |
| [Contributing](CONTRIBUTING.md) | You want to send a change. |

## Licence

Beacon is released under the MIT licence. See [LICENSE](https://github.com/Up-Coast/beacon/blob/main/LICENSE).
