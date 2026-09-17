# Beacon documentation

*Last updated: 2026-09-17*

Beacon puts a report button in your macOS or iOS app. Testers use it to send bugs, feature requests and feedback, and a Claude session works each report by a written triage policy.

## Getting Beacon

Pick one of three ways.

- **The plugin.** In Claude Code, run the two commands below, then ask Claude to "set up Beacon in my app". The `beacon-setup` skill walks one of the setup paths with you, and `beacon-triage` works the reports. The plugin carries the whole repository.

  ```text
  /plugin marketplace add Up-Coast/beacon
  /plugin install beacon@up-coast
  ```

- **The Swift package.** Add `https://github.com/Up-Coast/beacon.git` from version `0.2.2`. The [Quickstart](quickstart.md) shows the code. You still need a setup path so reports go somewhere.
- **A clone.** The setup pages assume the repository is at `~/beacon`.

  ```bash
  git clone https://github.com/Up-Coast/beacon.git ~/beacon
  ```

## Two setup paths

Choose one per app. Every account, token and page involved is yours.

| | Claude-only path | GitHub path |
|---|---|---|
| **Fits** | A team with a Claude organization that does not use GitHub | A team that tracks work in GitHub |
| **Reports go to** | Your Beacon page, a Claude artifact | Labelled issues in your repository |
| **Testers report from** | The Beacon page, opened by the button in your app | The in-app sheet, the Beacon page, or both |
| **Testers need** | Access to your Beacon page | For the sheet, a GitHub account with access to the repository. For the page, access to the page. |
| **A report carries** | App and device details from the link, plus what the tester writes and the images they add | From the sheet, also the app's log, settings, folder layout, screenshots, a screen recording and files |
| **The board** | Included | Optional |
| **Setup** | [Setup: the Claude-only path](setup-claude-only.md) | [Setup: the GitHub path](setup-github.md) |

On both paths a Claude session picks reports up, works them by [the triage policy](../Triage/TRIAGE.md), and records an outcome on every report. [What is collected](what-is-collected.md) lists everything a report carries.

## Set up a new app

1. Set up a path: [Claude-only](setup-claude-only.md) or [GitHub](setup-github.md).
2. Put the button in your app: [Quickstart](quickstart.md).
3. Send the testers [For testers](for-testers.md).
4. Watch reports arrive on [the board](the-board.md).

## Pages

| Page | Read it when |
|---|---|
| [Quickstart](quickstart.md) | You want the button in your app now. |
| [Setup: the Claude-only path](setup-claude-only.md) | You have a Claude organization and do not use GitHub. |
| [Setup: the GitHub path](setup-github.md) | You track work in GitHub and want issues and the in-app sheet. |
| [How it works](how-it-works.md) | You want to know what happens after a tester presses send. |
| [The board](the-board.md) | You want to see every report and its outcome. |
| [What happens to a report](what-happens-to-a-report.md) | You want to know what Claude does with a report, and what it never does. |
| [What is collected](what-is-collected.md) | You need to tell testers what a report contains. |
| [Options](options.md) | You want every configuration field, transport and flag. |
| [For testers](for-testers.md) | You want the page to send to your testers. |
| [FAQ](faq.md) | You want short answers to common questions. |

## Requirements

- An app for macOS 26 or iOS 26 or later.
- Xcode with the macOS 26 and iOS 26 SDKs, and Swift 6.2 or later.
- Claude Code, to run the pickup and, on the Claude-only path, to publish the page.
- On the GitHub path: a GitHub repository you administer, and the `gh` command-line tool signed in with access to it.
