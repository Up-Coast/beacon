---
name: beacon-setup
description: >
  Put Beacon — bug, feature-request and feedback reporting — into someone's
  macOS or iOS app, and set up the pickup that works the reports. Use when
  asked to "set up Beacon", "add Beacon to my app", "install Beacon", "add a
  feedback button", "get bug reports from my testers", "publish the Beacon
  page", or "set up the triage pickup". Walks one of the two setup paths
  (Claude-only, or GitHub) end to end from the documentation that ships with
  this skill, and never touches infrastructure the person did not ask for.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Artifact
---

# Setting Beacon up for someone

This skill lives at `.claude/skills/beacon-setup/` inside the Beacon
repository — a clone of it, or the copy this plugin installed. **Two
directories up from this file is the repository root**, and everything you
need is there: `docs/` (the public documentation, which is the source of
truth for every step below), `Scripts/`, `Triage/`, `Inbox/index.html` and
the Swift package itself. Find that root first:

```bash
BEACON="$(cd "$(dirname "<path to this SKILL.md>")/../../.." && pwd)"
ls "$BEACON/docs"
```

Read `docs/README.md` there before anything else. The steps below say what
order to do things in and what to ask; the pages under `docs/` say how, and
they win wherever the two seem to differ.

## 1. Find out which path

Ask, in one message, unless the answer is already clear from what they said:

- **Do they track work in GitHub?** No GitHub → the **Claude-only path**
  (`docs/setup-claude-only.md`): reports go to a page they own, and the board
  is the whole tracker. Yes → the **GitHub path** (`docs/setup-github.md`):
  reports become labelled issues, and the page is optional.
- **Which app, where is its source, and which platform** (macOS, iOS, both)?
- **Where should they be told when something happened?** A Slack channel
  through a connector, an email, or nowhere.

Do not ask for anything the documentation does not need.

## 2. Do the path, in the documentation's order

Follow the numbered steps of the chosen setup page exactly. In outline:

**Claude-only path**
1. Publish `Inbox/index.html` from the repository root as an artifact with
   the `db` and `artifact` capabilities and the favicon 🎇. Load the
   `artifact-capabilities` skill first if it is available. The link it gives
   back is their Beacon page; tell them to keep it.
2. Seed the `apps` collection with one document per app: `id`, `name`,
   `platform`, `folder`, `tracker: "board"`.
3. Put the button in the app (`docs/quickstart.md`, steps 1 to 3).
4. Set up the pickup (below).

**GitHub path**
1. Run `Scripts/beacon-adopt-github.sh <app checkout> <owner/repo>` from the
   repository root. It needs `gh` signed in. Commit what it copied.
2. Tell them to register a GitHub OAuth App with Device Flow enabled
   (`docs/setup-github.md`, step 2). **That is theirs to do** — it is a
   sign-in on their account. Ask for the Client ID when they have it.
3. Configure the app (`docs/setup-github.md`, step 4, and
   `docs/quickstart.md`).
4. Optionally publish the page and board, with each app's `tracker` set to
   `github` (the Claude-only path's steps 1 and 2).
5. Set up the pickup (below).

**The pickup, either path.** Copy the prompt from `Triage/PICKUP.md`, fill in
its four values (their page link, the path to this repository, the folder
their code lives under, and where to notify), and offer it as a scheduled
task in Claude Code or as a prompt they paste when they want a run. On the
GitHub path there is also the copied workflow, which needs the Claude GitHub
App and one secret — both theirs to add; say so and point at the setup page.

## 3. Prove it

Build the app, press the button, send a test report, and show them where it
landed: the board at their page link plus `?view=board`, or the issue in
their repository. A setup that has not filed one report is not finished.

## Never

- Create, change or delete anything on an account they did not ask you to
  touch: no OAuth Apps, no repository secrets, no GitHub App installs, no
  scheduled tasks they have not agreed to. Say what is theirs to do and stop.
- Enter a token, secret or password anywhere. The Client ID is public by
  design and is the only value you handle.
- Edit a published page by hand. `Inbox/index.html` is the one home;
  republish from it.
- Skip the test report.
