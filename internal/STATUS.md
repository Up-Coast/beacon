# Status

*Last updated: 2026-09-17*

What is proven by a test, what is proven by having run it, what is written but has never run, and what is known to be wrong. Every other page in this repository describes how Beacon works; this is the only page that says how far it has been taken. The tests themselves are listed in the [developer guide](DEVELOPER-GUIDE.md#tests).

## Proven by tests

`swift test` runs 110 tests in 28 suites on the Mac. The iOS Simulator runs the same suites, minus the keychain ones, which skip themselves there because a test host on the simulator has no keychain to write to.

| Proven | Where |
|---|---|
| The bug gate: three required fields, placeholder answers, answers under 12 characters, blank step rows, and the reproducibility nudge that must not block | `BeaconCoreTests` |
| The feature gate: an area or "something new" is required; the why is asked for and never required | `BeaconCoreTests` |
| Issue rendering: fixed headings, verbatim quoting including multi-line answers, numbered steps, the label set, that the app never sets severity, title derivation without cutting mid-word, and a metadata block that parses as JSON | `BeaconCoreTests` |
| The secret sweep: six credential shapes, settings passwords, URLs carrying passwords, host-declared secrets, short host secrets ignored, ordinary prose untouched, text attachments swept and binaries not, home directory redaction | `BeaconCoreTests` |
| Consent: acceptance per version and per person, rewording asks again, the notice names the organization and says the report is not anonymous | `BeaconCoreTests` |
| The app map: JSON round trip, a newer schema refused, hidden areas routable but not offered, sentinels always rendering a name | `BeaconCoreTests` |
| The inbox link: keys carried, blanks left out, existing query kept, and the Swift key list matching a copy of the page's list | `BeaconCoreTests` |
| The log ring, the folder scan (a known string written into a scanned tree is asserted absent), and the report archive | `BeaconDiagnosticsTests` |
| Transports: saving locally never claims to have filed, the fallback takes over and says why, attachment links leave the prose alone, GitHub status codes become sentences, an oversize relay report is refused before upload | `BeaconGitHubTests` |
| The signed-in account: a kept token comes back with its reporter, a second person replaces the first with no token left behind, signing out leaves nothing, and a report with nobody signed in is refused in words rather than sent without a token. These skip themselves where there is no usable keychain, which is every iOS Simulator run | `BeaconGitHubTests` |
| Refusals name the real cause: an unregistered Client ID says so rather than blaming the network, GitHub's own description wins when it sends one, and an unsigned build is told it has no keychain | `BeaconGitHubTests` |
| Attachments refused for want of write access (403, 404) let the issue go without them; a dead network does not | `BeaconGitHubTests` |
| Who a build offers reporting to: the App Store's environment maps to development, TestFlight and App Store, and `.testBuilds` keeps the button out of App Store builds | `BeaconTests` |
| `AppIdentity.mainBundle`: a bundle without the keys gives empty values rather than guesses, and the commit is kept because no bundle can know it | `BeaconCoreTests` |
| Seeding: both switches required, a missing folder is safe, every outcome explains itself | `BeaconCoreTests` |
| The on-device pass: unavailability is honest, questions override the model's own flag, blank questions dropped, an unknown field name falls back | `BeaconIntelligenceTests` |
| Capture without a screen: frames out of a real video as PNGs in time order, a picked video travels with frames, a picked photo loses its location and camera metadata, unreadable formats refused, sentences name the platform | `BeaconCaptureTests` |

## Proven by running it

| Proven | Last checked |
|---|---|
| `swift test` passes: 110 tests, 28 suites, Swift 6.3.3 on macOS | 2026-09-17 |
| The GitHub device flow, end to end against GitHub: an OAuth App registered with device flow on, `begin()` returning a code, the code accepted at github.com/login/device, the app authorized, and the token handed back to the app | 2026-09-17 |
| The sign-in screen inside a shipping app: Actually Keto on an iPhone 17 Pro simulator showed the report button in Settings, the sign-in step, the code copied for the tester, and the failure path with a Client ID that is not registered | 2026-09-17 |
| Beacon adopted by three iOS apps (Actually Keto, Neori, Dayletter): each builds against the tag, files to its own repository, and hides the button outside test builds | 2026-09-17 |
| `beacon-index` against this package: 8 areas, 28 screens. CI runs it on every push | 2026-09-17 |
| CI (build, test, self-index) green on `macos-26` | 2026-09-16 |
| The whole package builds for macOS 26 and the iOS 26 Simulator under strict concurrency with no warnings | 2026-09-07 |
| The sheet on iOS, walked end to end in `Examples/BeaconExample` on a simulator: walkthrough, consent, the bug form, a screenshot taken from inside the sheet that shows the app and not the form, the recording strip, a photo picked from the library, review with the full issue preview, the on-device check, and a report saved to the app's container with the log tail and the simulated device in it | 2026-09-07 |
| Filing to GitHub: `LiveTransportTests` against a private repository created the attachment branch, committed a file to it, and filed an issue with labels and the attachment linked | 2026-09-07 |
| The page published as an artifact with `db` and `artifact`: a real send became a report document, was filed as a GitHub issue by the pickup, and the outcome came back onto the board | 2026-09-07 |
| A cloud routine read the page's database with the Artifact tool. It could not file issues: no `gh`, no git credentials, and no Swift on a Linux runner | 2026-09-04 |

## Written, but never run

Nothing here is known to be broken. None of it has been proven right either.

| Not yet run | What is missing |
|---|---|
| The reporter's flow on macOS | Every view compiles and the same state machine runs, but nobody has walked it end to end in a real Mac app |
| Screen recording on either platform | The macOS path has never recorded a real window, and the first run needs Screen Recording permission granted by hand. On iOS the simulator's recorder starts and stops but writes an empty file, so a physical device is needed |
| The on-device check against the real model | It ran once on the iOS Simulator and asked nothing about a short, complete bug. What it says about a thin report is unknown, and the prompt will need tuning |
| A report filed from inside an app | The device flow, the transport and the filing calls are each proven, but no report has yet travelled the whole way from an app's sheet to an issue. What stopped it was the keychain, not the flow: see the unsigned-build gap below |
| `RelayTransport` | No relay is deployed |
| The triage policy and skill | Written and copied into app repositories. Reports have been filed as issues, and no run of the policy over an open issue is recorded |
| `beacon-reproduce.yml` | Ships failing at the run step until it is pointed at a host app's UI test scheme |

## Known gaps

- **An unsigned build cannot sign in.** Beacon keeps the token in the keychain, and a build with no signing team has no keychain: `SecItemAdd` returns `errSecMissingEntitlement` and the sheet says so. This is iOS, not Beacon, but it makes a command-line `xcodebuild` build useless for testing the sheet. Xcode builds signed with a team, and TestFlight builds, are fine. The same limit is why the keychain tests skip themselves on the iOS Simulator.
- **The committed page does not run.** In `Inbox/index.html`, `isBoard` reads `q` on the line above `q` is declared, so the script throws a `ReferenceError` at load and neither view works. The publish check (`new Function`) parses the script and does not run it, so it does not catch this.
- **The page has no automated tests.** The only check before publishing is that the script parses.
- **Nothing holds the page's copy of the rules equal to Swift.** `InboxLinkTests.everyKeyIsOneThePageReads` compares the Swift key list against a list copied into the test, not against `Inbox/index.html`. The completeness rules and their messages are copied by hand as well.
- **The page's reference can collide.** It is 3 random bytes, and the page writes `reports/<reference>` with `set`, which overwrites an existing document.
- **The secret sweep does not cover the issue title or the saved report.** It sweeps the rendered body and text attachments. A title derived from the reporter's first sentence is not swept, and `report.json` in the archive keeps the reporter's text and the log as written.
- **The iOS build is not in CI.** `ci.yml` builds and tests on macOS only, so an iOS-only break is found by hand.
- **`beacon-triage.yml` does not start `beacon-reproduce.yml`.** Its comment says the macOS leg is handed off; nothing in the workflow, the policy or the skill does that. A run that needs macOS has to be started by hand.
- **`beacon-triage.yml` reads only `CLAUDE_CODE_OAUTH_TOKEN`.** Its comment offers `ANTHROPIC_API_KEY` as an alternative, but the workflow never passes one.
- **The triage workflow in this repository is switched off.** It failed on every scheduled run because the Claude GitHub App is not installed here. It stays off until the owner asks for it.
- **Attachments on a private repository do not preview.** Images are committed to the `beacon-attachments` branch and link rather than render inline, because raw URLs on a private repository need authentication.
- **The doorbell waking a session has never been observed.** A send happened while a watch showed connected and no notice arrived. A scheduled pickup covers it either way.
- **A cloud routine cannot build, fix or reach a private repository.** It reads the page and can file; everything past that needs a machine with `gh`, git credentials and Swift.
- **The page carries no log tail, settings or folder shape.** Only the native sheet collects those. This is a deliberate limit, not an oversight.

## Open decisions

- **The name.** "Beacon" is an authored default. It is in the module names, so changing it is a rename across the package.
- **A relay.** None is deployed and none is planned until an adopter needs testers without GitHub accounts.
- **The iOS build in CI.** Adding it is a change to `ci.yml` and the owner's call.
- **Which way an app reports** is a per-app choice, not a decision Beacon makes. An app can start on the page and add the sheet later; both end in one queue and the board shows both. The two setup paths are in [the documentation](../docs/README.md).
