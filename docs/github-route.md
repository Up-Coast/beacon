# The GitHub route

*Last updated: 2026-09-07*

What the in-app report sheet adds over the Beacon page, and what it needs. Setting it up is
[Setup: the GitHub path](setup-github.md).

## What it adds

The Beacon page carries what fits in a link. The in-app sheet carries much more:

- **The app's own log.** The last few hundred lines, so what the app was doing just before
  the problem rides along without the tester describing it.
- **Your settings**, as you choose to describe them. Secrets are counted but never shown:
  "API key: set (not shown)".
- **The shape of named folders.** Names, nesting, sizes and dates — like a table of
  contents. Never the contents; the code that lists a folder never opens a file, and a
  test proves it.
- **A screenshot** of the app, one button. On the Mac it is the app's window; on iPhone
  and iPad it is drawn from the app's own screen, underneath the report form.
- **A screen recording** of the app itself. The tester presses record, makes the problem
  happen, presses stop. On iOS the form shrinks to a strip at the bottom while recording so
  the app stays usable behind it, and iOS asks the tester's permission first. Only the app
  is captured; nothing behind it, and no audio. Because a session cannot watch video, still
  frames are pulled from the recording at intervals and attached beside it.
- **Photos**, on iOS: screenshots and screen recordings the tester already took with the
  buttons every iPhone user knows, picked from the library. A video picked this way gets
  frames pulled out of it too.
- **Files** the tester chooses to attach.
- **An on-device read-through.** On a device with Apple Intelligence, its own model reads
  the report before it is sent and asks at most three follow-up questions. It never blocks,
  never rewrites a word, and nothing leaves the device for it.
- **A secret sweep.** Credential shapes and anything you declared secret are masked in the
  report text and every text attachment, and the tester is shown what was removed.

The report is filed straight into your repository as an issue, in a fixed layout with the
tester's words quoted exactly, labelled `beacon`, `type:…`, `impact:…` and `area:…`.
Attachments are committed to a `beacon-attachments` branch that nothing builds from and
linked from the issue. The session then works it exactly as it works a page report.

## What testers need

A GitHub account with access to the repository. The tester signs in once with GitHub's
device flow — a code shown in the app, entered on a GitHub page — and reports post under
their own account. No server, and no secret in the app. This is why the route fits an
internal team and not a public beta; for testers without GitHub accounts, put the Beacon
button in as well and their reports arrive on the page and are filed for them.

A relay is also shipped for teams that would rather run one small service holding a single
credential than have every tester sign in; see `RelayTransport` in [Options](options.md).

## Where it stands

- Filing: proven against a real repository on 2026-09-07 (branch created, attachment
  committed, issue created with labels) by a live test in the package that runs only when
  pointed at a repository on purpose.
- The sheet on iOS: walked end to end in the simulator on 2026-09-07 — consent, the bug
  form, a screenshot of the app taken from inside the sheet, the recording strip, review,
  the on-device check and a saved report. Screen recording itself has not yet produced a
  video on a physical device; the simulator's recorder starts but hands back nothing.
- The sheet on macOS: built and covered by tests, not yet walked end to end inside a
  shipping app.
- Platforms: macOS 26 and iOS 26, the same package.

## The one decision

Which route an app uses is a per-app choice. You can start on the Beacon page now and add
the sheet later; reports from both end in the same queue, and the board shows both.
