# Setup: the GitHub path

*Last updated: 2026-09-07*

For a technical team that tracks work in GitHub. Reports become labelled issues in your
repository, filed either straight from the app's own report sheet or from the Beacon page,
and a Claude session works the issue queue. Nothing here belongs to anyone else's account:
you register your own GitHub app, you hold your own tokens, and the board is optional.

About an hour, including the one-time GitHub registrations.

## What you end up with

- **Issues in your repository** for every report, in a fixed layout, labelled by kind,
  impact and area, with images on a branch nothing builds from.
- **Your apps**, each with the Beacon sheet or the Beacon button in it.
- **A pickup** that works the queue — on your Mac, or on GitHub's own runners.
- **Optionally, your Beacon page and board**, for testers without GitHub accounts and
  for a single place to see every report.

## 1. Get Beacon and put its pieces in your repository

```bash
git clone https://github.com/Up-Coast/beacon.git ~/beacon
~/beacon/Scripts/beacon-adopt-github.sh /path/to/your-app your-org/your-app
```

Or install the plugin instead and let your Claude run this page: [Getting Beacon](README.md#getting-beacon).

The script copies the triage policy, the triage skill, the two workflows and the issue
templates into your app's repository, and creates Beacon's labels on GitHub. It needs the
`gh` command-line tool signed in with access to the repository. Commit what it copied.

## 2. Register a GitHub OAuth App

This is what lets a tester sign in from inside your app, once, so reports post under their
own account. Beacon uses GitHub's device flow: the app shows a short code, the tester
enters it on a GitHub page, done. There is no client secret and nothing worth extracting
from the app.

From GitHub's own documentation:

1. In the upper-right corner of any page on GitHub, click your profile picture, then
   **Settings**. To register under an organisation instead, open the organisation's
   settings.
2. In the left sidebar, click **Developer settings**, then **OAuth apps**, then
   **New OAuth App**.
3. Fill in the application name, your homepage URL, and an authorization callback URL
   (any URL you own; the device flow does not use it).
4. Tick **Enable Device Flow**. The device flow does not work until this is on.
5. Register the app. Copy the **Client ID** from the app's page.

Put the Client ID in your app's configuration (see step 4). Ask only for the `repo` scope;
Beacon does.

## 3. Decide who runs the pickup

Two options; you can have both.

**On your Mac.** The prompt in [`Triage/PICKUP.md`](https://github.com/Up-Coast/beacon/blob/main/Triage/PICKUP.md)
becomes a scheduled task in Claude Code, or a session you run on demand. This is the only
option that can reproduce and prove a fix for a Mac or iOS app, because it has a Mac.

**On GitHub's runners.** The copied workflow `.github/workflows/beacon-triage.yml` runs the
triage skill on a weekday schedule, on Linux, and hands the reproduce-and-prove leg to
`beacon-reproduce.yml` on a macOS runner. Once, for that:

1. Install the Claude GitHub App on the repository: https://github.com/apps/claude, or run
   `/install-github-app` inside Claude Code, which also walks you through the secret. You
   must be a repository admin.
2. Add one repository secret: `CLAUDE_CODE_OAUTH_TOKEN` (Claude Pro and Max subscribers
   generate it with `claude setup-token`), or `ANTHROPIC_API_KEY` if you would rather bill
   the API.
3. Point `beacon-reproduce.yml` at your app's UI test scheme. It is shipped failing at that
   step on purpose, so a half-wired setup cannot report a green run that proved nothing.

The workflows carry the permissions the action needs: `contents: write`,
`issues: write`, `pull-requests: write`, `id-token: write`. macOS runner minutes cost about
ten times Linux minutes; the workflow only uses one when a report needs reproducing.

## 4. Configure the app

Follow the [Quickstart](quickstart.md) steps 1 and 2. For `transport`, replace the
placeholder with the direct transport, wrapped so a network outage never loses a report:

```swift
// Once, when the tester first reports: sign them in.
let flow = GitHubDeviceFlow(clientID: "<your OAuth App's Client ID>")
let challenge = try await flow.begin()
// Show challenge.userCode and open challenge.verificationURL
let token = try await flow.awaitToken(challenge)
GitHubTokenStore.save(token, account: reporter.accountID)

// At launch:
transport: FallbackTransport(
    primary: GitHubIssueTransport(
        client: GitHubClient(owner: "your-org", repository: "your-app",
                             token: GitHubTokenStore.read(account: account) ?? "")),
    fallback: LocalBundleTransport(folderProvider: { lastSavedReportFolder }))
```

Then put the sheet in: `BeaconReportButton()` anywhere, or `.beaconReportSheet(isPresented:)`
on your own button, and `.beaconWalkthroughOnFirstRun()` on your main view so new testers
are shown how, once. Run the indexer in your build so the "which part of the app" picker is
real:

```bash
swift run beacon-index --source . --output Resources/BeaconIndex.json \
    --app-name "Harbour" --commit "$(git rev-parse HEAD)"
```

The sheet works the same on macOS and iOS. For testers without GitHub accounts, put the
Beacon button in as well (Quickstart step 3); those reports arrive on the page and the
pickup files them as issues in the same repository, in the same format.

## 5. Optional: the board

If you want one page with every report and its outcome — or you have any tester who is
not on GitHub — publish the Beacon page too. Follow [Setup: the Claude-only path](setup-claude-only.md)
steps 2 and 3, with each app's `tracker` set to `github` instead of `board`. The pickup
then files page reports as issues and mirrors every issue's outcome back to the board.

Skip this and the queue lives entirely in GitHub.

## 6. Tell your testers

Send them [For testers](for-testers.md). Testers using the in-app sheet need a GitHub
account with access to the repository; testers using the page need to be members of your
Claude organisation.

## Later

- **A new app**: run the adoption script for its repository, register nothing new — one
  OAuth App serves every app under the same GitHub account or organisation.
- **A newer Beacon**: `git pull` in `~/beacon`, re-run the adoption script (it replaces its
  own files and leaves yours alone), and bump the package version in your app.
