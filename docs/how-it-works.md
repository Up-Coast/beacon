# How it works

*Last updated: 2026-10-13*

A report goes from a button in your app, to a record on your Beacon page or an issue on GitHub, to a Claude session that works it and writes the outcome back.

## A report's journey

1. **The tester opens the report form.** `BeaconInboxButton` opens your Beacon page in the browser, on its form. The link carries what the app already knows: app, version, build, commit, operating system, device, language, time zone, appearance and text size. [Options](options.md) lists every key. With the GitHub setup, the app can show Beacon's in-app sheet instead, which files a GitHub issue itself.
2. **The tester writes what only they know.** They pick one of four kinds: **Something's broken**, **Something's missing**, **Change request**, for something that works but should work differently, or **Something else**. A bug needs what happened, what they expected, and the steps. The form refuses answers that say nothing, such as "n/a" or "it broke". Every report also asks how much the problem affects the tester. Images are shrunk on the tester's device before they are sent.
3. **The page stores the report.** It gets a reference such as `BN-8EA6C3` and the status `new`. The tester sees the reference on a receipt, and their part is done.
4. **The page rings the doorbell.** It publishes a new version of itself, which tells a Claude session watching the page that a report arrived. If the publish fails, the report is still stored and waits for the next scheduled pickup.
5. **The pickup files the report.** A Claude session, or a scheduled task, runs the prompt in [PICKUP.md](../Triage/PICKUP.md). For an app whose `tracker` is `github`, the report becomes an issue in the app's repository, and its status becomes `filed`. If the same problem is already filed, the report is added to that issue as a comment, and a closed issue is reopened. For an app whose `tracker` is `board`, the report stays on the page and is worked there.
6. **The pickup triages the report.** It follows the triage policy in [TRIAGE.md](../Triage/TRIAGE.md): is it complete, is it a bug, does it reproduce, is the fix simple. A bug that passes goes into To do. [The worker](../Triage/WORKER.md), an hourly task, builds what is in To do, proves it by running the app and merges it, or flags it **Blocked** and says why. [What happens to a report](what-happens-to-a-report.md) summarizes the policy.
7. **The outcome goes back onto the report.** The pickup writes the status, the finding, a short note for you, and the fixing commit when there is one. The [dashboard](the-board.md) shows all of it.

Before it investigates, the pickup reads what earlier reports for the same app already found. A report that repeats one already worked gets that report's status, finding and note, and is not worked again.

## Statuses

The dashboard shows a status on every report. The page stores it as a value. Every value from `needs-info` down is also a GitHub label with the same name, set by triage. `new`, `filed` and `triaging` exist only on the page.

### Status

A status is a step in a report's life. A column and its status share a name, so a card is in the column of its status. They are listed in column order, then the three ways a report ends without a column.

| The dashboard shows | Value | Meaning |
|---|---|---|
| Backlog | `backlog` | Kept open and not being worked on now. You park a report here by moving it to the Backlog column; moving it out puts back what it was. An issue labelled `backlog` shows here too. |
| Inbox | `new`, `filed` | Sent, and nobody has triaged it. `new` is not yet an issue; `filed` has an issue in the app's repository. The next daily check triages it. |
| To Triage | `triaged`, `needs-human`, `needs-info`, `cannot-reproduce`, `expectation-mismatch` | Triage read it and it is not going to To do: it needs something first, or it is yours to move. A flag beside it can say why (below). |
| To do | `todo`, `approved` | Queued for the next run. Triage puts a bug it can fix itself here automatically (`todo`); you put anything else here by approving it or dragging it to To do (`approved`). |
| In progress | `triaging` | A session is working on it now. |
| Done | `auto-fixed` | Fixed, proven by running the app, and merged. Also an issue a session closed as finished. |
| Deployed | `deployed` | The fix is live. |
| Closed: works as designed | `working-as-intended` | The app behaves as designed. The explanation is on the issue, which is closed. |
| Closed: canceled | `declined`, `closed` | Not doing it. `declined` is you canceling it; `closed` is an issue closed as not planned. |
| Closed: duplicate | `duplicate` | A copy of another report. A report that names another with `duplicateOf` shows as Closed: duplicate too. |

Closed is one thing with four reasons: works as designed, canceled, duplicate and feedback. None is a column, all four close the issue, and everything that treats a report as closed (Hide done, the Closed section, the mirror and push scripts) treats them the same.
| Closed: feedback | `feedback-closed` | Feedback you read and closed without work. The issue is closed as completed and labelled `feedback-closed`. |

### Flags

A flag says more about a report than its status does. A report has one status and any number of flags. Flags show beside the status and can be filtered on. They come from the report's stored value, and a session can add its own in a `flags` list. **Needs your decision** is only for a report that truly needs your call; a report that is just To Triage is not asking for one.

| The dashboard shows | Value | Meaning |
|---|---|---|
| Needs your decision | `needs-human` | Triage cannot go on without your call: it is a product or business choice. Whether to fix a bug is never one; a reproduced bug goes to To do. The report must carry triage's recommendation in its `decision` field: approve or decline, in one or two plain sentences, with the reason the report does not already give. No question and no list of choices: approving or declining the report is the choice. The dashboard shows it under the title, and says plainly when it is missing. |
| Needs more info | `needs-info` | Something the report needs is missing. The question is recorded on the issue, for you to ask the tester or not. |
| Can't reproduce | `cannot-reproduce` | Three attempts failed. What was tried is written down. Nobody may work on it. |
| Confusing to users | `expectation-mismatch` | The app did what it should, but the tester expected something else. A separate report about the gap is opened. |
| Waiting for human | `flags` list only | Yours to set in Your changes, and set by triage on a ticket only a person can do. The report can sit in To do, but the worker leaves it completely alone until you clear the flag. It is one of two things that hold an approved report back. |
| Needs PR approval | `flags` list only | Yours to set in Your changes. The worker does the work but opens a pull request instead of merging, and you merge it. |
| Ask Claude | `flags` list only | Yours to set with a question in your note. The worker answers it in `claudeReply` and on the issue, builds nothing, then unticks it and ticks Waiting for human. |
| Blocked | `flags` list, with `blocked` | Set by the worker when it cannot finish a report: it comments on the issue and writes the reason on the report. The report stays in To do and the worker skips it until you clear the flag. |

A report that has a GitHub issue shows its ticket number, such as `UCP-163`, stored as `ticket`. [Ticket numbers](the-board.md#ticket-numbers) says how it is built.

A status value the page does not know shows as the value itself. You set To do, Backlog and the four Closed reasons on the dashboard (the Status menu, or Move to). The mirror script sets Closed: canceled and Closed: duplicate from an issue closed as not planned or as a duplicate (Triage/PICKUP.md, Part 0).

## Columns

The dashboard's board layout puts each report in a column. The report stores it as `column`, with the time it last moved as `columnAt`. The pickup sets it as it works, and you move cards on [the dashboard](the-board.md#move-a-card).

| Column | Value | Set by |
|---|---|---|
| Backlog | `backlog` | You, by parking it. |
| Inbox | `reported` | Every new report starts here. |
| To Triage | `todo` | The pickup, for everything it does not queue. You, by withdrawing an approval. |
| To do | `upnext` | The pickup, for a bug it will fix on its own. You, by approving. |
| In progress | `inprogress` | The worker, when it starts the work. |
| Done | `done` | The worker, when the change is merged to the main branch. |
| Deployed | `deployed` | You, when the fix is live. The pickup, when it can tell. |

(The ids are older than the names: `todo` is the To Triage column and `upnext` is To do.)

A report with no `column`, such as one sent before columns existed, is placed by its status: received and filed in Inbox, anything waiting on your decision in To Triage, approved and being looked at in Up next, fixed in Done. The status also wins when it and the column disagree: a fixed report is never shown before Done, an approved or worked one never before Up next, and one waiting on your decision is always in To Triage. Declined reports, reports closed as not planned, and reports that work as designed are shown under Closed, not in a column.


## What Beacon needs to run

- **Your Beacon page**, published from `Inbox/index.html` into your Claude organization. Testers open it signed in to Claude as members of that organization.
- **Something that runs the pickup**: a Claude session watching the page, a scheduled task, or both. Reproducing and proving a fix for a macOS or iOS app needs macOS: your Mac, or a GitHub-hosted macOS runner.
- **For apps tracked on GitHub**: the `gh` command-line tool, signed in with access to the repository, on the machine that runs the pickup.

The setup steps are in [Setup: the Claude-only path](setup-claude-only.md) and [Setup: the GitHub path](setup-github.md).
