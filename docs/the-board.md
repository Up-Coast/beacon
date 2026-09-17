# The board

*Last updated: 2026-09-17*

The board lists every report from every app on your Beacon page, and what happened to each. It is read-only: the pickup writes the outcomes.

## Open it

Add `?view=board` to your Beacon page's link:

```text
https://claude.ai/code/artifact/…?view=board
```

The same page without `?view=board` is the report form. The board updates live, newest report first, and shows the latest 500.

## Read a row

Each row shows the report's title, its status, and one line with the reference, kind, app and version, who sent it, when, and how many images it has.

Open a row to see the whole report:

| Part | What it shows |
|---|---|
| **Facts** | Impact, reporter, app with version and build, commit, operating system and device, language and time zone, appearance and text size, area, when it was filed, repository, and the fixing commit. |
| **The tester's words** | For a bug: what they expected, what happened, the steps, and whether it happens again. For a request: what they want and why. For anything else: their message. |
| **Finding** | The verdict, what the product is supposed to do, and where in the source that is written down. |
| **Triage note** | Two to four sentences from the pickup, written for you: what it found and what happens next. |
| **Issue** | A link to the GitHub issue, once the report is filed. |
| **Images** | Loaded when you open the row. |

A part with nothing in it is left out. What each status means is in [How it works](how-it-works.md#statuses).

## Filter

| Filter | Choices |
|---|---|
| App | Every app, or one app from the page's app list. |
| Status | Every status, or one status. |
| Kind | Every kind, Bugs, Requests or Feedback. |
| Search words | Matches the title, the tester's words, the reporter, the area and the reference. |

The count shows how many reports match, out of the total.

## Who can see it

Anyone who can open your Beacon page can add `?view=board` and see every report. The form alone never shows other people's reports.

## Apps tracked on the board only

An app whose `tracker` is `board` has no GitHub repository. Its reports are never filed anywhere else. The pickup works each one on the page and writes the outcome here, so the board is the whole tracker. [Options](options.md) describes the app list.
