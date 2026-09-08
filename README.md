# Beacon

A bug, feature-request and feedback reporting system you drop into an app.

The reporter presses a button inside the app. Beacon collects the version,
the machine, the settings, the folder layout and the last few hundred lines
of log; makes them read what's being sent; refuses a bug report that's
missing what makes a bug report actionable; has the device's own on-device
model read it over and ask the obvious follow-up; and files it as a GitHub
issue with labels that route it. On the other side, an agent works the
queue against a written policy — reproduce or don't touch it, check what
the product is *supposed* to do before deciding anything is a bug, fix only
what's genuinely small, and prove the fix by running the app.

Runs on macOS 26 and iOS 26. The same sheet, the same rules and the same
transports on both; only the capture layer differs, and it presents one
shape — ScreenCaptureKit on the Mac, ReplayKit and the app's own view
hierarchy on iPhone and iPad.

Two ways to set it up, neither tied to anyone's accounts: the Claude-only
path and the GitHub path. Both are in [docs/](docs/README.md).

---

## Getting it

Your Claude can install it and do the setup for you:

```
/plugin marketplace add Up-Coast/beacon
/plugin install beacon@up-coast
```

then ask it to *set up Beacon in my app*. The plugin carries the whole
repository, so the setup skill has the documentation, the scripts and the
page, and the triage skill has the policy. The other ways in — the Swift
package alone, or a clone — are in [docs/README.md](docs/README.md#getting-beacon).

---

## Adopting it, in three steps

**1. Depend on it and configure it once.**

```swift
.package(url: "https://github.com/Up-Coast/beacon.git", from: "0.1.0")
```

```swift
import Beacon

Beacon.configure(BeaconConfiguration(
    app: AppIdentity(name: "Harbour",
                     bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                     version: "1.4.2", build: "318",
                     commit: BuildInfo.commit),
    organizationName: "the Harbour team",
    currentReporter: { Account.signedIn.map { Reporter(accountID: $0.email,
                                                       displayName: $0.name) } },
    transport: GitHubIssueTransport(
        client: GitHubClient(owner: "your-org", repository: "harbour",
                             token: token)),
    index: BeaconIndex.loadFromBundle(.main),
    settings: { Settings.current.beaconEntries },
    fileTreeRoots: [FileTreeRoot(label: "Your projects", url: Paths.projects)]))
```

**2. Put the button somewhere.**

```swift
BeaconReportButton()                       // ready-made
.beaconReportSheet(isPresented: $reporting) // or your own button
.beaconWalkthroughOnFirstRun()              // shows new testers how, once
```

**3. Index the app in your build.**

```bash
swift run beacon-index --source . --output Resources/BeaconIndex.json \
    --app-name Harbour --commit "$(git rev-parse HEAD)"
```

That produces the map behind every "which part of the app?" picker, and it
is what lets triage turn a label back into source paths. Regenerate it on
every build — a hand-kept list is wrong within a month.

Full walkthrough with the pieces you can swap: [internal/ADOPTING.md](internal/ADOPTING.md).

---

## What's in the box

| | |
|---|---|
| `BeaconCore` | Report types, the completeness rules, issue rendering, the secret sweep, the app map, the transport seam. No UI, no platform APIs. |
| `BeaconDiagnostics` | The log Beacon brings with it, the environment probe, the names-only folder scan, the on-disk archive. |
| `BeaconIntelligence` | The on-device completeness check, on Apple's Foundation Models. |
| `BeaconCapture` | Screenshots and screen recording of the host app itself — its own window on macOS, its own screen on iOS — plus frames pulled out of every video. |
| `BeaconGitHub` | Three transports, plus GitHub device-flow sign-in. |
| `BeaconUI` | The reporter's flow, and the walkthrough. |
| `Beacon` | The façade — what a host app imports. |
| `beacon-index` | The indexer. |
| `Examples/BeaconExample` | The smallest host app Beacon can be walked in, for iPhone, iPad and Mac. `xcodegen generate` in that folder makes the project. |
| `Inbox/` | The shared inbox page — the browser route, for testers inside the owner's Claude organisation. |
| `docs/` | **The public documentation** — for a founder or developer putting Beacon in their app: what it is, the quickstart, how it works, the board, the policy in plain words, what is collected, options, the two setup paths, what the in-app sheet adds, FAQ. |
| `internal/` | **For people working on Beacon itself** — `DEVELOPER-GUIDE.md` is the full technical reference (modules, the report, the page's schema, every call the pickup and the transports make, the CLI, the tests); plus the adoption walkthrough, status, privacy audit and cloud-reproduction notes. |
| `Triage/TRIAGE.md` | The triage policy. |
| `Triage/PICKUP.md` | The pickup prompt anyone gives their Claude — account-free. |
| `Scripts/beacon-adopt-github.sh` | One command that puts the GitHub-side pieces into an app's repository. |
| `.claude/skills/beacon-triage/` | The skill that runs it. |
| `.claude/skills/beacon-setup/` | The skill that puts Beacon into an app and sets up the pickup. |
| `.claude-plugin/` | The plugin manifest and the marketplace entry, so a Claude installs both skills with two commands. |

## The decisions worth knowing about

**A bug report can't be filed without what it expects, what happened, and
the steps.** Enforced deterministically, so it holds on every machine
whether or not there's an on-device model. Empty-but-filled-in answers
("n/a", "it broke", "asdf") are refused too.

**The on-device check asks, it never blocks.** It reads the report on the
reporter's own Mac, asks at most three questions, never rewrites a word,
and "send it anyway" is always available. Where there's no on-device model,
the report says so rather than implying it was reviewed.

**Nothing goes to Private Cloud Compute or any server.** The check runs on
`SystemLanguageModel.default` or not at all.

**Beacon reads *about* files, never inside them.** The folder scan calls
`contentsOfDirectory` and `resourceValues` and never opens a file handle —
it can't read contents because it never asks for them. Files the reporter
attaches are the exception, chosen one at a time.

**Reports are not anonymous, and the reporter is told so first.** The
consent wording is versioned; changing it asks everyone again, and the
version they accepted is recorded on their report.

**The secret sweep runs last and tells the reporter what it found.** Silent
scrubbing hides a real leak in the host app's logging.

**Only formats the triaging agent can read are accepted.** Text, images,
PDFs, video. A recording always travels with still frames pulled out of it,
because an agent can't watch a video.

**Only the host app itself is captured.** On the Mac, `SCShareableContent.currentProcess`
returns only this process's windows, so a recording cannot pick up whatever
is behind the app. On iOS a screenshot is drawn from the app's own view
hierarchy and a recording goes through ReplayKit, which records this app's
screen only and asks the person first. The reporter doesn't have to trust
that it won't see anything else.

**The app never sets severity.** The reporter answers how much it costs
*them*; severity is how much it costs *everyone*, and that's triage's call.

**A report is saved to disk before it's sent.** A failed send is an
inconvenience, not a lost report.

## Running the tests

On the Mac:

```bash
swift test
```

The same suites on the iOS Simulator, plus one that only means anything there:

```bash
xcodebuild test -scheme Beacon-Package -destination 'platform=iOS Simulator,name=iPhone Air'
```

To walk the sheet itself, generate and run the example app: see
[Examples/BeaconExample/README.md](Examples/BeaconExample/README.md).

## Licence and status

MIT, see [LICENSE](LICENSE); changes are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md). Version 0.1.0 — the shape is settled and the flow is
complete; see [internal/STATUS.md](internal/STATUS.md) for what is proven by tests,
what is proven by running it, and what is still on paper.
