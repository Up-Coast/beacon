# How it works

*Last updated: 2026-10-13*

A report goes from a button in your app, to a record on your Beacon page or an issue on GitHub, to a Claude session that works it and writes the outcome back.

## A report's journey

1. **The tester opens the report form.** `BeaconInboxButton` opens your Beacon page in the browser, on its form. The link carries what the app already knows: app, version, build, commit, operating system, device, language, time zone, appearance and text size. [Options](options.md) lists every key. With the GitHub setup, the app can show Beacon's in-app sheet instead, which files a GitHub issue itself.
2. **The tester writes what only they know.** They pick one of four kinds: **Something's broken**, **Something's missing**, **Change request**, for something that works but should work differently, or **Something else**. A bug needs what happened, what they expected, and the steps. The form refuses answers that say nothing, such as "n/a" or "it broke". Every report also asks how much the problem affects the tester. Images are shrunk on the tester's device before they are sent.
3. **The page stores the report.** It gets a reference such as `BN-8EA6C3` and the status `new`. The tester sees the reference on a receipt, and their part is done.
4. **The page rings the doorbell.** It publishes a new version of itself, which tells a Claude session watching the page that a report arrived. If the publish fails, the report is still stored and waits for the next scheduled pickup.
5. **The pickup files the report.** A Claude session, or a scheduled task, runs the prompt in [PICKUP.md](../Triage/PICKUP.md). For an app whose `tracker` is `github`, the report becomes an issue in the app's repository, and its status becomes `filed`. If the same problem is already filed, the report is added to that issue as a comment, and a closed issue is reopened. For an app whose `tracker` is `board`, the report stays on the page and is worked there.
6. **The pickup works the report.** It follows the triage policy in [TRIAGE.md](../Triage/TRIAGE.md): is it complete, is it a bug, does it reproduce, is the fix simple, then fix it and prove the fix by running the app. [What happens to a report](what-happens-to-a-report.md) summarizes the policy.
7. **The outcome goes back onto the report.** The pickup writes the status, the finding, a short note for you, and the fixing commit when there is one. The [dashboard](the-board.md) shows all of it.

Before it investigates, the pickup reads what earlier reports for the same app already found. A report that repeats one already worked gets that report's status, finding and note, and is not worked again.

## Statuses

The dashboard shows a status on every report. The page stores it as a value. Every value from `needs-info` down is also a GitHub label with the same name, set by triage. `new`, `filed` and `triaging` exist only on the page.

| The dashboard shows | Value | Meaning |
|---|---|---|
| Received | `new` | Sent, not yet picked up. |
| Filed | `filed` | An issue exists for it in the app's repository. |
| Being looked at | `triaging` | A session is working on it now. |
| Needs more from the tester | `needs-info` | Something the report needs is missing. The question is recorded on the issue, for you to ask the tester or not. |
| Couldn't reproduce | `cannot-reproduce` | Three attempts failed. What was tried is written down. Nobody may work on it. |
| Working as designed | `working-as-intended` | The app behaves as designed. The explanation is on the issue, which is closed. |
| App isn't explaining itself | `expectation-mismatch` | The app did what it should, but the tester expected something else. A separate report about the gap is opened. |
| Needs a person | `needs-human` | The fix is past what may be done unattended. A written diagnosis is attached. |
| Fixed | `auto-fixed` | Fixed, proven by running the app, and merged. |
| Triaged | `triaged` | Read, labelled and routed. Waiting on a person. |

A status value the page does not know shows as the value itself. Two more values come from you on the dashboard: `approved` (Approved, waiting for the next run) and `declined`. One more comes from the issue: `closed` (Closed, not planned) is a report whose issue was closed as not planned, which the mirror script sets (Triage/PICKUP.md, Part 0).

## Columns

The dashboard's board layout puts each report in a column. The report stores it as `column`, with the time it last moved as `columnAt`. The pickup sets it as it works, and you move cards on [the dashboard](the-board.md#move-a-card).

| Column | Value | Set by |
|---|---|---|
| Reported | `reported` | Every new report starts here. |
| Triaged | `todo` | The pickup, for everything that waits on you. You, by withdrawing an approval. |
| Up next | `upnext` | The pickup, for a bug it will fix on its own. You, by approving. |
| Done | `done` | The pickup, when the fix is merged to the main branch. |
| Deployed | `deployed` | You, when the fix is live. The pickup, when it can tell. |

A report with no `column`, such as one sent before columns existed, is placed by its status: received and filed in Reported, anything waiting on your decision in Triaged, approved and being looked at in Up next, fixed in Done. The status also wins when it and the column disagree: a fixed report is never shown before Done, an approved or worked one never before Up next, and one waiting on your decision is always in Triaged. Declined reports, reports closed as not planned, and reports that work as designed are shown under Closed, not in a column.


## What Beacon needs to run

- **Your Beacon page**, published from `Inbox/index.html` into your Claude organization. Testers open it signed in to Claude as members of that organization.
- **Something that runs the pickup**: a Claude session watching the page, a scheduled task, or both. Reproducing and proving a fix for a macOS or iOS app needs macOS: your Mac, or a GitHub-hosted macOS runner.
- **For apps tracked on GitHub**: the `gh` command-line tool, signed in with access to the repository, on the machine that runs the pickup.

The setup steps are in [Setup: the Claude-only path](setup-claude-only.md) and [Setup: the GitHub path](setup-github.md).
