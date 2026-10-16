# Setup: the Claude-only path

*Last updated: 2026-10-16*

Reports go to a Beacon page that your Claude organization owns. A Claude session works them, and the dashboard on the page is your whole tracker, for every app you add. No GitHub is needed.

You end up with:

| Piece | What it is |
|---|---|
| Your Beacon page | A Claude artifact published from `Inbox/index.html`. Testers use its form. You use its dashboard. |
| Your app list | One entry per app, added in the page's **Apps** view. |
| The Beacon button | In each app. It opens the page with the app's details filled in. |
| The pickup | A daily scheduled task that reads new reports, triages them and decides what goes into To do. |
| The worker | An hourly scheduled task that builds what is in To do, or flags it **Blocked** and says why. |

## 1. Get Beacon

```bash
git clone https://github.com/Up-Coast/beacon.git ~/beacon
```

To have Claude run this page for you instead, install the plugin. See [Getting Beacon](README.md#getting-beacon).

## 2. Publish your page and add your apps

1. Open Claude Code in `~/beacon`.
2. Ask Claude to publish the page:

    > Publish `Inbox/index.html` as an artifact with the `db` and `artifact` capabilities and the favicon 🎇.

3. Keep the artifact link Claude gives you. It is your Beacon page link.
4. Open the link. The page opens on the dashboard and says **No apps yet**.
5. Click **Add your first app**. Fill in the app's name and platform, choose **On this page** under **Where reports are worked**, and give the folder its source lives in, relative to the code folder you give the pickup in step 4. Click **Save the app**. Add each other app the same way from **Apps**, **Add an app**.
6. Share the page with each tester from the page's share menu, with edit access.

[The dashboard](the-board.md#add-and-change-apps) describes every field, and [Options](options.md#the-app-list-on-the-page) how the pickup reads them.

A page with a database is internal to your Claude organization and cannot be shared publicly. Every tester must be a signed-in member of the organization. Testers need edit access because sending a report publishes a new version of the page, and that new version is what tells a watching Claude session a report arrived.

## 3. Put the button in your app

1. Follow [Quickstart](quickstart.md) steps 1 to 3, using your page link.
2. Build the app, press the button and send a test report.
3. Open your page link. The report is on the dashboard, under the app's tab.

## 4. Set up the pickup

1. Copy the prompt from [the pickup prompt](../Triage/PICKUP.md).
2. Fill in the four values at its top: your page link, your Beacon checkout (`~/beacon`), the folder your apps' source lives under, and how you want to be told when something happened.
3. Choose how it runs:
    - **Scheduled.** In Claude Code on the Mac that has your apps' source, ask Claude to create a scheduled task with the prompt.
    - **On demand.** Paste the prompt into a Claude Code session when you want a run.

The pickup needs `gh` signed in to your GitHub account and `python3`. Each run copies the issues onto the dashboard and copies what you changed on the dashboard back to the issues, so run it daily. Pressing **Run now** applies a change at once.

## 5. Set up the worker

1. Copy the prompt from [the worker prompt](../Triage/WORKER.md).
2. Fill in the values at its top. They are the same as the pickup's.
3. In the Claude desktop app, ask Claude to create a scheduled task with the prompt, running hourly, with the permission mode set to Auto.

When the worker cannot finish a report, it comments on the issue, flags the report **Blocked** and writes why on the dashboard. Answer in your note, then untick **Blocked** to send it back. [The worker prompt](../Triage/WORKER.md) lists the reasons it stops.

Run the pickup and the worker on a Mac. Reproducing a report and proving a fix means building and running a macOS or iOS app, and that needs a Mac. What the pickup does with each report is in [What happens to a report](what-happens-to-a-report.md).

## 6. Tell your testers

Send them [For testers](for-testers.md), and tell them where the button is in your app.

## Later

- **Add an app.** Open the page, click **Apps**, then **Add an app**. The page needs no republish.
- **Update Beacon.** Run `git pull` in `~/beacon`, then ask Claude to republish `Inbox/index.html` to the same artifact. Reports and the app list stay.
- **Move an app to GitHub.** Follow [Setup: the GitHub path](setup-github.md), then in **Apps**, click **Change** on the app, choose **As GitHub issues** and give its repository. The dashboard keeps working.
