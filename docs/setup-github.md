# Setup: the GitHub path

*Last updated: 2026-09-17*

Reports become labelled issues in your app's GitHub repository. The app files them itself through Beacon's in-app report sheet, under each tester's own GitHub account. A Claude session or a GitHub Actions workflow works the issues. The Beacon page and board are optional.

You need admin access to the repository and the GitHub CLI, `gh`, signed in.

## What the in-app sheet adds

The Beacon page carries what fits in a link, plus the tester's words and images. The in-app sheet also sends:

- the last lines of the app's log
- your settings, with secrets counted but not shown
- the names and structure of folders you choose, never their contents
- a screenshot or a screen recording of the app's own windows, with still frames taken from the recording
- photos and videos from the photo library, on iOS
- files the tester attaches

Before sending, it masks anything that looks like a credential, and on a device with Apple Intelligence it asks the tester up to three follow-up questions. Details are in [What is collected](what-is-collected.md).

## 1. Copy Beacon's files into your repository

1. Clone Beacon:

    ```bash
    git clone https://github.com/Up-Coast/beacon.git ~/beacon
    ```

2. Run the adoption script against a checkout of your app's repository:

    ```bash
    ~/beacon/Scripts/beacon-adopt-github.sh /path/to/harbour your-org/harbour
    ```

3. Commit and push what it copied.

To have Claude run this page for you instead, install the plugin. See [Getting Beacon](README.md#getting-beacon).

| The script adds | Where |
|---|---|
| The triage policy and the pickup prompt | `Triage/TRIAGE.md`, `Triage/PICKUP.md` |
| The triage skill | `.claude/skills/beacon-triage/` |
| The two workflows | `.github/workflows/beacon-triage.yml`, `.github/workflows/beacon-reproduce.yml` |
| Issue templates | `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml`, `config.yml` |
| A folder for reproduction seed data | `Triage/seeds/` (empty) |
| Beacon's labels, on GitHub | `beacon`, `type:*`, `impact:*`, `severity:*` and the triage outcome labels |

The script replaces its own files and leaves every other file alone, so it is safe to re-run. `area:<id>` labels are created as reports arrive. It does not register an OAuth App, install the Claude GitHub App or add secrets. Those are steps 2 and 3.

## 2. Register a GitHub OAuth App

The OAuth App lets a tester sign in to GitHub from inside your app, once. Beacon uses GitHub's device flow: the app shows a code, and the tester enters it on a GitHub page. The device flow needs no client secret, so the only value in your app is the public Client ID. One OAuth App serves all your apps.

1. On GitHub, click your profile picture, then **Settings**. To register the app under an organization, open that organization's settings instead.
2. Click **Developer settings**, then **OAuth apps**, then **New OAuth App**. If this is your first app, the button is **Register a new application**.
3. Fill in **Application name** and **Homepage URL**.
4. Fill in **Authorization callback URL** with any URL you own. The device flow does not use it.
5. Tick **Enable Device Flow**.
6. Untick **Expire user access tokens**. Beacon stores the token it receives and does not refresh it, so an expiring token would stop working.
7. Click **Register application**.
8. Copy the **Client ID**. You use it in step 4.

If the repository belongs to an organization with OAuth app access restrictions, an organization owner must approve the OAuth App. GitHub turns these restrictions on by default for new organizations.

## 3. Choose where the pickup runs

You can use one option or both.

### On your Mac

1. Copy the prompt from [the pickup prompt](../Triage/PICKUP.md) and fill in the four values at its top.
2. In Claude Code on the Mac that has your app's source, ask Claude to create a scheduled task with the prompt, or paste it into a session when you want a run.

Only a Mac can reproduce a report and prove a fix by building and running a macOS or iOS app.

### On GitHub Actions

`beacon-triage.yml` runs the `beacon-triage` skill on Linux at 08:00 UTC on weekdays. You can also start it from the Actions tab, optionally for one issue number.

1. Install the [Claude GitHub App](https://github.com/apps/claude) on the repository. Running `/install-github-app` in Claude Code also installs it.
2. Add the repository secret `CLAUDE_CODE_OAUTH_TOKEN`. Generate the token by running `claude setup-token`. It uses your Claude Pro, Max, Team or Enterprise plan.
3. To bill the Claude API instead, add the secret `ANTHROPIC_API_KEY`. Then, in `beacon-triage.yml`, replace the `claude_code_oauth_token` line with:

    ```yaml
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    ```

4. To reproduce reports on a GitHub-hosted macOS runner, edit `beacon-reproduce.yml`. Replace its **Build** step with your app's build, and its **Run the reporter's steps** step with your app's UI test. That step fails on purpose until you do, so a run that proved nothing never shows as passing. Start the workflow by hand from the Actions tab. [Reproducing on GitHub-hosted macOS runners](../internal/CLOUD-REPRODUCTION.md) covers the runner and its cost.

GitHub runs scheduled workflows only from the default branch. In a public repository, GitHub switches the schedule off after 60 days with no repository activity.

## 4. Configure the app

1. Follow [Quickstart](quickstart.md) steps 1 and 2.
2. Replace the `Beacon.configure` call with this one. `GitHubAccount` holds the OAuth App's Client ID, remembers who signed in, and reads their token from the keychain when a report is sent.

    ```swift
    import Beacon

    @MainActor
    func configureBeacon() {
        let account = GitHubAccount(clientID: "<your OAuth App's Client ID>")
        Beacon.configure(
            BeaconConfiguration(
                app: AppIdentity(/* as in the quickstart */),
                organizationName: "the Harbour team",
                currentReporter: { account.reporter },
                transport: FallbackTransport(
                    primary: SignedInGitHubIssueTransport(
                        owner: "your-org", repository: "harbour", account: account),
                    fallback: LocalBundleTransport(folderProvider: {
                        ReportArchive(directory: BeaconConfiguration
                            .defaultArchiveDirectory(appName: "Harbour")).saved().first
                    }))),
            gitHubAccount: account,
            audience: .testBuilds)
    }
    ```

    The sheet asks a tester who is not signed in to sign in to GitHub, and shows the code and the GitHub page itself. `audience: .testBuilds` hides the report button and the walkthrough in App Store builds. Pass `.everyone` to show them in every build. If GitHub cannot be reached, the report is kept on the device and the tester is told where.

3. Put the sheet in. Use `BeaconReportButton()` anywhere, or `.beaconReportSheet(isPresented:)` on your own button.
4. Add `.beaconWalkthroughOnFirstRun()` to your main view. New testers see how to report, once.
5. Generate the app map that fills the sheet's "which part of the app" picker. Run this from your app's repository:

    ```bash
    swift run --package-path ~/beacon beacon-index \
        --source . \
        --output Harbour/Resources/BeaconIndex.json \
        --app-name "Harbour" \
        --commit "$(git rev-parse HEAD)"
    ```

6. Add `BeaconIndex.json` to your app target as a resource, and pass `index: BeaconIndex.loadFromBundle(.main)` to `BeaconConfiguration`.
7. Build the app, sign in, and send a test report. It appears as an issue labelled `beacon`.

    Build it signed, with a development team. Beacon keeps the tester's GitHub token in the keychain, and an unsigned build has no keychain: the sign-in comes back and cannot be kept, and the sheet says so. A build from Xcode with your own team, or a TestFlight build, is fine. A command-line `xcodebuild` run with no team is not.

The sheet works the same on macOS and iOS. To sign testers in yourself instead, leave `gitHubAccount` out and use `GitHubDeviceFlow` and `GitHubIssueTransport` directly. For platform permissions, the full list of fields and the indexer's options, see [Options](options.md).

## 5. Optional: publish the Beacon page

Publish the page if some testers have no GitHub account, or if you want one board with every report.

1. Follow [Setup: the Claude-only path](setup-claude-only.md) step 2. Set each app's `tracker` to `github`, and set `repository` to its `owner/name`.
2. Put the Beacon button in the app as well ([Quickstart](quickstart.md) step 3).

The pickup files page reports as issues in the same repository and format, and writes each outcome back to the board. Without the page, the whole queue lives in GitHub.

## 6. Tell your testers

1. Give each tester who uses the in-app sheet push (write) access to the repository. Anyone who can read the repository can file a report, but GitHub silently drops the labels triage looks for, and refuses the attachments. The issue then says the files stayed on the tester's device.
2. Send them [For testers](for-testers.md).

Testers who use the Beacon page need to be signed-in members of your Claude organization instead.

## Later

- **Add an app.** Run the adoption script against its repository. The same OAuth App serves it.
- **Update Beacon.** Run `git pull` in `~/beacon`, re-run the adoption script, and raise the package version in your app.
