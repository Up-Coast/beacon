# Setup: the Claude-only path

*Last updated: 2026-09-17*

Reports go to a Beacon page that your Claude organization owns. A Claude session works them, and the board on the page is your whole tracker. No GitHub is needed.

You end up with:

| Piece | What it is |
|---|---|
| Your Beacon page | A Claude artifact published from `Inbox/index.html`. Testers use its form. You use its board. |
| Your app list | One entry per app, stored in the page's database. |
| The Beacon button | In each app. It opens the page with the app's details filled in. |
| The pickup | A Claude session or scheduled task that reads new reports and works them. |

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
4. Ask Claude to add one document per app to the page's `apps` collection, with `tracker` set to `board`. The example below shows one app.
5. Share the page with each tester from the page's share menu, with edit access.

| Document id | `name` | `platform` | `folder` | `tracker` |
|---|---|---|---|---|
| `harbour` | Harbour | `macOS` | `harbour` | `board` |

`folder` is where the app's source lives, relative to the code folder you give the pickup in step 4. Every field is described in [Options](options.md#the-app-list-on-the-page).

A page with a database is internal to your Claude organization and cannot be shared publicly. Every tester must be a signed-in member of the organization. Testers need edit access because sending a report publishes a new version of the page, and that new version is what tells a watching Claude session a report arrived.

## 3. Put the button in your app

1. Follow [Quickstart](quickstart.md) steps 1 to 3, using your page link.
2. Build the app, press the button and send a test report.
3. Open your page link with `?view=board` added. The report is on the board.

## 4. Set up the pickup

1. Copy the prompt from [the pickup prompt](../Triage/PICKUP.md).
2. Fill in the four values at its top: your page link, your Beacon checkout (`~/beacon`), the folder your apps' source lives under, and how you want to be told when something happened.
3. Choose how it runs:
    - **Scheduled.** In Claude Code on the Mac that has your apps' source, ask Claude to create a scheduled task with the prompt.
    - **On demand.** Paste the prompt into a Claude Code session when you want a run.

Run the pickup on a Mac. Reproducing a report and proving a fix means building and running a macOS or iOS app, and that needs a Mac. What the pickup does with each report is in [What happens to a report](what-happens-to-a-report.md).

## 5. Tell your testers

Send them [For testers](for-testers.md), and tell them where the button is in your app.

## Later

- **Add an app.** Ask Claude to add a document to the `apps` collection. The page needs no republish.
- **Update Beacon.** Run `git pull` in `~/beacon`, then ask Claude to republish `Inbox/index.html` to the same artifact. Reports and the app list stay.
- **Move an app to GitHub.** Follow [Setup: the GitHub path](setup-github.md), then change that app's `tracker` to `github`. The board keeps working.
