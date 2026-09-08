# The board

*Last updated: 2026-09-07*

One page with every report from every app you own, and what happened to each.

## Opening it

Your Beacon page has two faces. Opened plainly, it is the form testers fill in. Add
`?view=board` to the same link and it is your board:

```
https://claude.ai/code/artifact/…?view=board
```

Bookmark that. It updates live; a report sent while you are looking appears at the top.

## Reading it

Each row is one report: its title, a status pill, and a line with the reference, the
kind, the app and version, who sent it, when, and how many images it carries.

Open a row and you get the whole record:

- **The tester's words**, exactly as written. What they expected, what happened, the
  numbered steps, whether it happens again; or what they want and why; or their message.
- **The facts the app supplied.** Impact, version, build, commit, device, operating
  system, language, appearance and text size, the area of the app if they named one.
- **The images**, loaded when you open the row.
- **The issue**, as a link, once it has been filed in the repository.
- **The finding.** What the product is supposed to do at that point and where in the
  source that is written down, and the verdict: bug, working as designed, the app not
  explaining itself, request, or feedback.
- **The note.** Two to four plain sentences from the session about what it found and what
  happens next. Written for you, not the tester.
- **The fix**, as a commit reference, when one was made.

## Filters

Narrow by app, by status, by kind, or by any word in the report. The count shows how many
of the total you are looking at.

## Statuses

The status vocabulary is the same everywhere: on the board, on the GitHub issue, in the
session's own policy. [How it works](how-it-works.md#statuses) lists each one.

## Who can see it

Anyone who can open your Beacon page can open the board. Today that means signed-in
members of your Claude organisation. Testers do not need to know the board exists, and the
form never shows them other people's reports.

## Apps tracked on the board alone

If an app has no GitHub repository, set its tracker to "board" ([Options](options.md)).
Reports for it are never filed anywhere else; the session works each one in place and
writes the outcome here. The board is the whole tracker.
