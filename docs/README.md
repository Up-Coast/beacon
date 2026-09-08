# Beacon

*Last updated: 2026-09-07*

Beacon is the feedback system inside your app. A tester presses one button, says what
happened, and the report reaches your engineering team already carrying the app version,
the build, the device and the machine. Bugs, feature requests and general feedback all
travel the same way. On the other side, a Claude session picks each report up, works out
whether it is a real bug, reproduces it, and fixes what it can — without anyone waiting
for a person.

## Who this is for

- **Founders.** You want to know what your testers are running into, and you want the
  small things fixed before you have read about them. Beacon gives you one page with every
  report and what happened to it. The [board](the-board.md) is where you will spend your time.
- **Developers adding Beacon to an app.** One dependency, one configuration call, one
  button. The [Quickstart](quickstart.md) takes about fifteen minutes.
- **Testers.** You never need to read any of this. There is a short page written for you:
  [Reporting something, if you're testing an app](for-testers.md).

## Two setup paths

Beacon is not tied to anyone's accounts. You choose one of two paths, and everything you
set up is yours.

| | The Claude-only path | The GitHub path |
|---|---|---|
| **For** | A founder or team with a Claude organisation and no GitHub | A technical team that tracks work in GitHub |
| **Reports go to** | Your Beacon page; the board is the whole tracker | Labelled issues in your repository, from the app's own sheet or from the page |
| **Testers need** | A Claude account in your organisation | A GitHub account with access to the repository (or a Claude account, for the page) |
| **What a report carries** | What fits in a link, plus what the tester writes and attaches | Also the app's log, its settings, folder shape, screenshots and a screen recording |
| **Works on** | macOS and iOS | macOS and iOS, the sheet and the page alike |
| **The board** | Included | Optional |
| **Setup** | [Setup: the Claude-only path](setup-claude-only.md) | [Setup: the GitHub path](setup-github.md) |

Both paths end in the same place: a queue that a Claude session works through by a written
policy, and an outcome on every report.

## Getting Beacon

Three ways in; pick the one that fits how you work.

- **Let your Claude do it.** In Claude Code:

  ```
  /plugin marketplace add Up-Coast/beacon
  /plugin install beacon@up-coast
  ```

  Then ask it to *set up Beacon in my app*. The plugin brings two skills:
  `beacon-setup`, which walks one of the setup paths below with you, and
  `beacon-triage`, which works the reports. It carries the whole repository, so
  nothing else needs cloning.
- **The Swift package alone.** Add `https://github.com/Up-Coast/beacon.git` as a
  dependency, from version `0.1.0`. The [Quickstart](quickstart.md) shows the code.
  You still need one of the setup paths for the reports to go somewhere.
- **A clone.** `git clone https://github.com/Up-Coast/beacon.git ~/beacon`. The
  setup pages assume this layout; the plugin's installed copy works the same way.

## The path for a new app

1. **Pick your path and set it up.** [Claude-only](setup-claude-only.md) or [GitHub](setup-github.md).
2. **Put the button in.** [Quickstart](quickstart.md).
3. **Understand what happens after a tester presses send.** [How it works](how-it-works.md).
4. **Open your board.** Every report, filterable, with the outcome. [The board](the-board.md).
5. **Read what Claude will and will not do with a report.** [What happens to a report](what-happens-to-a-report.md).
6. **Check what is collected, so you can tell your testers.** [What is collected](what-is-collected.md).

## Pages

| Page | Read it when |
|---|---|
| [Setup: the Claude-only path](setup-claude-only.md) | you have a Claude organisation and no GitHub |
| [Setup: the GitHub path](setup-github.md) | you track work in GitHub and want issues, the in-app sheet, and optionally the board |
| [Quickstart](quickstart.md) | you want the button in your app now |
| [How it works](how-it-works.md) | you want to understand what runs, and when |
| [For testers](for-testers.md) | you are handing the app to someone and want to tell them how to report |
| [The board](the-board.md) | you want to see your reports and what happened to each |
| [What happens to a report](what-happens-to-a-report.md) | you want to know what Claude does with a report, and what it never does |
| [What is collected](what-is-collected.md) | you need to tell testers what a report contains |
| [Options](options.md) | you want to change what the app sends or how reports are routed |
| [The GitHub route](github-route.md) | you want to know what the in-app sheet adds over the page |
| [FAQ](faq.md) | short answers to common questions |

## Requirements

- An app for macOS 26 or iOS 26 or later, built with Swift Package Manager or Xcode.
- On the Claude-only path: a Claude organisation. Reports live in a page owned by it, and
  each tester must be a signed-in member of that organisation to send one.
- On the GitHub path: a GitHub repository you administer, and the `gh` command-line tool.
- A Claude session, scheduled task, or GitHub workflow that picks reports up. Each setup
  page says how.
