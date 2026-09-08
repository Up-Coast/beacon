# Setup: the Claude-only path

*Last updated: 2026-09-07*

For a founder or team with a Claude organisation and no GitHub. Reports go to a page you
own, a Claude session works them, and your board is the whole tracker. Nothing here belongs
to anyone else's account; when you are done, every piece is yours.

About thirty minutes, most of it waiting for builds.

## What you end up with

- **Your Beacon page**, published from the Beacon repository into your own Claude
  organisation, with the form for testers and the board for you.
- **Your app list** on that page, one entry per app.
- **A pickup** — a scheduled task in Claude Code on a Mac, or a session you run when you
  want — that reads new reports and works them by the policy.
- **Your apps**, each with the Beacon button in it.

## 1. Get Beacon

```bash
git clone https://github.com/Up-Coast/beacon.git ~/beacon
```

Or install the plugin instead and let your Claude run this page: [Getting Beacon](README.md#getting-beacon).

## 2. Publish your page

Open Claude Code in `~/beacon` and ask it, in these words:

> Publish `Inbox/index.html` as an artifact with the `db` and `artifact` capabilities and
> the favicon 🎇. Then seed the `apps` collection with my apps.

Give it your apps as a list: a short id, the name, the platform (macOS or iOS), and where
the source lives on the machine that will run the pickup. For this path every app's
`tracker` is `board`. For example:

| id | name | platform | folder | tracker |
|---|---|---|---|---|
| `harbour` | Harbour | macOS | `~/Code/harbour` | board |

Claude publishes the page and writes the list. The artifact link it gives you is your
Beacon page; keep it. The page is private to your organisation by design — a page with a
database cannot be shared publicly — so every tester must be a signed-in member of it. Share
it from the page's share menu with edit access.

## 3. Put the button in your app

Follow the [Quickstart](quickstart.md) steps 1 to 3, using your page link. Build, press the
button, send a test report, and open your board at your page link plus `?view=board`. The
report is there.

## 4. Set up the pickup

The pickup is a task you give to Claude. The prompt is written for you in
[`Triage/PICKUP.md`](https://github.com/Up-Coast/beacon/blob/main/Triage/PICKUP.md); fill in
the four values at its top (your page link, your Beacon checkout, where your code lives,
and how you want to be told when something happened) and then either:

- **Scheduled.** In Claude Code on the Mac that has your apps' source, ask Claude to create
  a scheduled task with that prompt, on the cadence you want. It runs while the Claude app
  is open, and a missed run fires at next launch.
- **On demand.** Paste the prompt into a Claude Code session whenever you want a run.

What the pickup will and won't do is [What happens to a report](what-happens-to-a-report.md).
It needs a Mac to reproduce and prove fixes for Mac and iOS apps; a cloud routine can pick
reports up but cannot build them.

## 5. Tell your testers

Send them [For testers](for-testers.md). They need to be members of your Claude
organisation, and to know where the button is.

## Later

- **Add an app**: ask Claude to add it to the `apps` collection. No republish.
- **Take a newer Beacon**: `git pull` in `~/beacon`, then ask Claude to republish
  `Inbox/index.html` to the same artifact. Your reports and app list stay.
- **Move to GitHub** for an app: [Setup: the GitHub path](setup-github.md), then change
  that app's `tracker` to `github`. The board keeps working.
