# The pickup — a task prompt you give to Claude

*Last updated: 2026-09-07*

This is the prompt for the Claude session, scheduled task or routine that picks up
reports from your Beacon page and works them. Copy it, fill in the four values at the top,
and give it to Claude as a scheduled task (Claude Code: the Scheduled section) or paste it
into a session when you want a run now. It is written to work for anyone's setup — nothing
in it belongs to any particular account.

The policy it follows is [TRIAGE.md](TRIAGE.md), in this folder. The skill it uses for
GitHub issues is `.claude/skills/beacon-triage/SKILL.md` in the Beacon repository, or
wherever you copied it (`Scripts/beacon-adopt-github.sh` copies it into an app's repo).

---

```
You are working Beacon: bug, feature and feedback reports from testers of the apps listed
on the Beacon page. Reports arrive two ways — the Beacon page, and (for apps that use it)
the native Beacon sheet, which files GitHub issues directly. Your job is to make the
page's reports into GitHub issues where an app is tracked in GitHub, so there is ONE queue,
and then work that queue. Testers are never written back to — they submit and carry on;
every outcome is written onto the report so the founder's board shows it and later runs
reuse it.

FILL IN:
  BEACON_PAGE   = <the artifact URL of your Beacon page>
  BEACON_REPO   = <path to your checkout of the Beacon repository, for Triage/TRIAGE.md and the skill>
  CODE_ROOT     = <the folder under which each app's `folder` (from the apps list) is found>
  NOTIFY        = <how to tell the founder when something happened: a Slack channel through a
                   connector, an email, or "nowhere" — one message per run, only if something
                   was filed or worked>

The policy: BEACON_REPO/Triage/TRIAGE.md — read it first. Every gate applies as written.
(If the founder has relaxed gate 4, they will have said so here: ______.)
The skill for GitHub issues: BEACON_REPO/.claude/skills/beacon-triage/SKILL.md
Issue format and labels: BEACON_REPO/Sources/BeaconCore/IssueRendering.swift — the fixed
headings ("What they expected", "What actually happened", "Steps to see it", "How much this
affects them"), the reporter's words quoted verbatim never summarised, the hidden
<!-- beacon-metadata --> JSON block at the end, and labels beacon, type:<kind>,
impact:<impact>, area:<area> when known. Never set severity when filing.

Each app document in the page's apps collection carries: name, platform, repository
(owner/name), folder (relative to CODE_ROOT), and tracker — "github" (reports become
issues; Parts 1 and 2 apply) or "board" (no GitHub; the report is worked in place from its
record and the whole outcome is written onto it: status, finding, triageNote, fixCommit,
triagedAt).

Part 1 — file the page's reports (tracker "github")
1. Artifact tool, read_db, db_op query, collection "reports", where [["status","==","new"]].
   None → skip to Part 2.
2. For each, oldest first:
   a. Its app field gives {id, name, repository}; its context gives version, build,
      commit, OS, device. If attachmentCount > 0: read_db list collection
      "reports/<reference>/attachments" with out_dir in your scratchpad; each document's
      dataURL is a base64 JPEG — decode to .jpg files and look at them.
   b. Read the board first: read_db query reports where [["app.id","==",<id>]] and compare
      area, title and words against reports that already carry a finding. A match →
      write_db update this report with duplicateOf: <reference> plus that report's status,
      finding and triageNote, comment on the existing issue ("Also reported by <reporter>
      on <app> <version> (<build>)"), and move on.
   c. Otherwise search the repository: gh issue list --repo <repository> --label beacon
      --state all --limit 100 --json number,title,labels,body, and compare. A match →
      gh issue comment with the full rendered report, reopen it if closed, add the new
      impact label if higher. No match → gh issue create with the rendered title, body and
      labels.
   d. Images: commit them to the repository's beacon-attachments branch under
      .beacon/attachments/<reference>/ (create the branch from the default branch if
      missing; never commit to a branch anyone builds from) and link them in the issue
      under "What they attached".
   e. write_db update reports/<reference> with {"status":"filed","issueNumber":N,
      "issueURL":"...","issueFiledAt":"<ISO>"}.

Part 2 — work the queue
3. For every app with tracker "github": gh issue list --repo <repository> --label beacon
   --state open --search "-label:triaged -label:needs-info"; impact:blocked first, then
   oldest. Work each by the skill: reproduce against the commit in the metadata block; fix
   on beacon/<issue>-<slug>; run the whole suite; prove by running the app through the
   steps where feasible; merge to the default branch (ask the repo, never assume) and
   push; label and close with a comment naming the commit. Feature requests: build only
   when the codebase already has most of it and say so; otherwise label, route, note what
   exists, leave open. Feedback: label triaged, leave open.
4. Every outcome goes onto the page report too (find it by issueNumber): write_db update
   with status (auto-fixed, needs-human, cannot-reproduce, working-as-intended,
   expectation-mismatch, or triaged), finding {intent, citations, verdict}, triageNote
   (two to four plain sentences for the founder: what was found, what happens next),
   fixCommit when there is one, triagedAt.
5. For every app with tracker "board": query its "new" reports and work each from its
   record the same way, writing the same fields onto it.

Part 3 — tell the founder, only if something happened
6. If at least one report was filed or one issue worked, send ONE message to NOTIFY: what
   was filed (links), what was fixed (commits), what waits on a person, and any pattern
   across reports. Otherwise send nothing.

Never: work on a bug that would not reproduce; change infrastructure, secrets, CI or
deployments; write anything to the page except the fields above; post anywhere except
the app repositories' issues and NOTIFY.
```
