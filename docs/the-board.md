# The dashboard

*Last updated: 2026-10-13*

The dashboard is where the owner reads every report from every app on the Beacon page, and what happened to each. One page serves all your apps: each app has its own tab, with its own counts. The pickup writes the outcomes. The one thing you write is your decision on work that waits on a person.

## Open it

Open your Beacon page link. The page opens on the dashboard:

```text
https://claude.ai/code/artifact/…
```

The bar at the top of the page switches between three views:

| View | What it is |
|---|---|
| **Reports** | The dashboard. |
| **Send a report** | The report form testers fill in. |
| **Apps** | The list of apps the page collects reports for. See [Add and change apps](#add-and-change-apps). |

The switch works inside the page, so it works however the link was opened. A link from the Beacon button inside an app opens the form instead, because it carries the app's name and details. To send someone straight to the form from a plain link, add `?view=form`. `?view=board` opens the dashboard, as the plain link does.

The dashboard updates live, newest report first, and loads the latest 1,000. A long list or column shows 25 cards (50 rows in the list layout) and a **Show more** button for the next page; changing the app, a filter or the search starts over.

![The dashboard showing all apps: a tab per app, four counts, the filters, and the reports that wait on a decision listed first](assets/page-dashboard.png)

The dashboard, the Apps view and the form in these pictures show made-up sample apps and reports.

## Set up the dashboard from scratch

1. **Publish the page.** In Claude Code, in your Beacon checkout, ask Claude to publish `Inbox/index.html` as an artifact with the `db` and `artifact` capabilities. Keep the link. [Setup: the Claude-only path](setup-claude-only.md) step 2 has the exact request.
2. **Open the link.** The page opens on the dashboard. With no apps yet, it shows **No apps yet**.
3. **Add your first app.** Click **Add your first app**, fill in the name, platform and where its reports are worked, and click **Save the app**. The fields are under [Add and change apps](#add-and-change-apps).
4. **Share the page** with each tester, with edit access, from the page's share menu.
5. **Point the app at the page.** Put the Beacon button in the app with the page link ([Quickstart](quickstart.md) steps 1 to 3). The button opens the page's form with the app chosen and its version, build and device filled in.
6. **Send a test report** from the app, then click **Reports**. The report is on the dashboard under the app's tab.

Where each way of reporting sends people:

| How the tester reports | Where they go | Where the report lands |
|---|---|---|
| The Beacon button in a Mac or iPhone app (`BeaconInboxButton`) | This page's form, with the app chosen | This page. The pickup works it here, or files it as a GitHub issue when the app's reports are worked as GitHub issues. Either way it stays on the dashboard with its outcome. |
| The in-app report sheet (`BeaconSheet`) | A sheet inside the app | A GitHub issue in the app's repository, directly or through the [relay](setup-relay.md). It does not reach this page. |
| The web sheet on a website | A sheet on the site | A GitHub issue through the relay ([Setup: a website](setup-web.md)). It does not reach this page. |
| The page link, opened plainly | The dashboard. **Send a report** opens the form, where the tester picks the app. | This page. |

## Run several projects on one dashboard

One page serves every app. There is no page per project.

1. Add each app in the **Apps** view: one entry per app, each with its own short id. A Mac app and its iPhone version can be one app or two; two gives each its own tab.
2. Use the same page link in every app's Beacon button. The link from each app names the app, so its reports land under its own tab.
3. Choose, per app, where its reports are worked:
    - **On this page.** The pickup works the report on the page. The dashboard is the whole record.
    - **As GitHub issues.** The pickup files each page report as an issue in the app's repository, then writes the outcome back onto the report, so it shows on the dashboard like any other. Reports that the in-app or web sheet files straight to GitHub stay in GitHub; the app's tab says so and links to its issues.
4. Read everything under **All apps**, or one app at a time with its tab. Each tab's number counts that app's reports waiting on your decision, and the four counts follow the tab you choose.

The pickup reads the same app list, so it knows each app's repository, folder and where its reports are worked. Adding an app needs no republish and no change to the pickup.

## List or board

The **List** and **Board** switch beside the filters changes how the dashboard lays out the reports. The page remembers the choice on this browser. The tabs, counts and filters work the same in both.

- **List**: reports waiting on your decision first, then everything else, newest first or highest impact first.
- **Board**: one column per stage, left to right. Within a column, the highest impact comes first, then the oldest.

![The dashboard's board layout: the Reported, Triaged, Up next, Done and Deployed columns, each card with its impact icon, status and a Move to menu](assets/page-kanban.png)

| Column | What is in it |
|---|---|
| **Reported** | Received, not triaged yet. |
| **Triaged** | Triaged, and waiting on you: needs a person, couldn't reproduce, needs more from the tester, the app isn't explaining itself, feature and change requests, and feedback. |
| **Up next** | What the pickup works on next: bugs it will fix on its own, and anything you approved. |
| **Done** | Fixed and merged to the main branch. |
| **Deployed** | The fix is live for the people using the app. |

Declined reports and reports that work as designed are not in a column. They are under **Closed**, below the board, folded away until you open it.

Click a card's title to open the whole report, the same detail a list row shows, Approve and Decline included.

![A card opened from the board: the report's detail in a panel over the board, with Approve the fix and Decline](assets/page-kanban-card.png)

### Move a card

With a mouse, drag the card itself. With a finger, drag it by its grip, the dotted square at its foot, so a swipe anywhere else still scrolls. Or choose a column from its **Move to** menu, which works from the keyboard. Only people who can edit the page see the grip and the menu. Every card moves to every column, closed cards included.

| Where it lands | What it does |
|---|---|
| Up next | Approves it, exactly as **Approve the fix** or **Approve building it** does, unless it is already approved or being worked. The next pickup works it. Feedback can go here too: the pickup acts on it. |
| Out of Up next, before work starts | Withdraws your approval and puts back the status it had. |
| Any other column | Moves the card and nothing else. The pickup leaves a card where you put it; the only cards it moves are the ones it triages out of Reported (into Triaged for you, or Up next for bugs it fixes) and the ones it finishes (into Done). |
| Back from Closed | Reopens it as triaged, in the column you chose. |

## Choose an app

The tabs under the heading are **All apps**, then one tab per app in the app list, with its platform: macOS, iOS, Web or Other. A number on a tab counts that app's reports waiting on your decision. The page remembers the tab you chose on this browser. A link with `?app=<id or name>` and nothing else opens on that app's tab.

A report whose app is not in the app list still shows, under a tab with a dashed border named after the app on the report. This happens when an app is removed from the list, or when a report names an app the list never had. That tab offers **Add this app**, which opens the Apps view with the name, id, platform and repository filled in from the report.

An app whose reports are worked as GitHub issues sends nothing to this page from its in-app sheet or website. Its tab says so and links to its issues.

## Read the counts

Four counts sit under the tabs, for the selected app or for all apps:

| Count | Reports counted |
|---|---|
| **Waiting on you** | Reports that wait on your decision: the pickup stopped on them and nobody has approved or declined them. Feedback is never counted here. |
| **Received** | Sent, not yet picked up. |
| **In progress** | Filed, being looked at, or approved and waiting for the next run. |
| **Fixed** | Fixed, proven and merged. |

Click a count to show only those reports. Click it again to show everything.

## Read a row

Reports that wait on your decision come first, under **Waiting on your decision**, each marked **Your decision**. Everything else follows.

Each row shows an impact icon, the report's title, its status, and one line with the reference, kind, app and version, who sent it, when, and how many images it has.

Open a row to see the whole report:

![A report that waits on a decision, opened: the Your decision box with Approve the fix and Decline, then the facts and the tester's words](assets/page-decision.png)

| Part | What it shows |
|---|---|
| **Your decision** | Approve and Decline, on a report that waits on you. Your decision, once made. |
| **Facts** | Impact, reporter, app with version and build, platform, commit, operating system and device, language and time zone, appearance and text size, area, when it was filed, repository, and the fixing commit. |
| **The tester's words** | For a bug: what they expected, what happened, the steps, and whether it happens again. For a request: what they want, what makes it hard, and their idea. For a change request: what to change, what instead, and why. For anything else: their message. |
| **Finding** | The verdict, what the product is supposed to do, and where in the source that is written down. |
| **Triage note** | Two to four sentences from the pickup, written for you: what it found and what happens next. |
| **Issue** | A link to the GitHub issue, once the report is filed. |
| **Images** | Loaded when you open the row. |

A part with nothing in it is left out. What each status means is in [How it works](how-it-works.md#statuses).

## Impact

Every report carries the tester's answer to "How much is this affecting you?". The dashboard shows it as an icon before the title, and again with its wording under **Impact** when the row is open. Each level has its own shape, so the icons differ without colour. Hover over an icon to read its wording.

| Icon | Impact | The tester's answer |
|---|---|---|
| A red stop sign | `blocked` | I can't do what I came to do |
| An amber warning triangle | `slowed` | I found a way around it, but it costs me time |
| An outlined circle with an exclamation mark | `irritating` | It bothers me, but I can keep working |
| A small open circle | `noticed` | I noticed it — it doesn't really affect me |

To see the worst first, choose **Highest impact first** in the order menu. To see one level only, choose it in the impact menu.

## Approve or decline

A report the pickup could not finish on its own, such as a fix too big to merge without a person or a feature request, shows **Your decision** when you open it, in the list or from a card on the board. On the board, dragging the card from Triaged to Up next is the same approval, with no note. Add a note if the work should do or avoid something, then click **Approve the fix** (or **Approve building it**) or **Decline**.

- **Approve:** the report shows "Approved, waiting for the next run". The next pickup builds it, merges it and writes the commit onto the report.
- **Decline:** the pickup closes the issue with your note.

Anyone who can edit the page can click these, so share edit access only with people you trust to decide.

## Filter

| Filter | Choices |
|---|---|
| App | The tabs. |
| Status | Every status, or one status. |
| Kind | Every kind, Bugs, Requests, Change requests or Feedback. |
| Impact | Every impact, or one level. |
| Order | In the list: newest first, or highest impact first, newest first within a level. On the board, each column is always highest impact first, then oldest. |
| Search words | Matches the title, the tester's words, the reporter, the area and the reference. |

The count beside the search box shows how many reports match, out of the selected app's total.

## Add and change apps

The **Apps** view lists every app the page collects reports for, and how many reports each has on the page. No database editing and no republish is needed.

![The Apps view: one card per app with Change and Remove, a dashed card for an app that is not in the list with Add this app, and the Add an app button](assets/page-apps.png)

1. Click **Apps** in the bar at the top, then **Add an app**.
2. Fill in the fields and click **Save the app**.

| Field | What it is |
|---|---|
| **Name** | What testers see in the app picker. Required. |
| **Short id** | Lowercase letters, numbers and single hyphens, such as `harbour`. Filled in from the name. Reports carry it, and the link's `app` key can name it. It cannot be changed once the app is saved. |
| **Platform** | macOS, iOS, Web or Other. |
| **Where reports are worked** | **On this page**: the pickup works each report on the page, and the dashboard is the whole tracker. **As GitHub issues**: the pickup files each report as an issue in the repository. |
| **Repository** | `owner/name`. Required when reports are worked as GitHub issues. |
| **Folder** | Where the app's source is, relative to the code folder the pickup works in. Optional. |

**Change** opens the same fields for an app. **Remove** asks first, and says how many reports the app has. Removing an app never deletes its reports: they stay on the dashboard under the app's name, and testers can no longer pick it.

When the page has no apps yet, the dashboard says so and offers **Add your first app**.

![The dashboard before any app is added: No apps yet, and the Add your first app button](assets/page-first-run.png)

Only people who can edit the page can add, change or remove apps. Anyone else sees the list without the buttons.

## Who can see it

Anyone who can open your Beacon page can open the dashboard and see every report. The form never shows other people's reports.

## Apps tracked on the dashboard only

An app whose reports are worked on this page has no GitHub repository behind it. Its reports are never filed anywhere else. The pickup works each one on the page and writes the outcome here, so the dashboard is the whole tracker. In the app list this is `tracker: "board"`. [Options](options.md#the-app-list-on-the-page) describes every field.
