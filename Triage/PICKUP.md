# The pickup — a task prompt you give to Claude

*Last updated: 2026-10-13*

The pickup is the prompt for a Claude session, scheduled task or routine that collects reports from your Beacon page and works them. Nothing in it belongs to any particular account, so it works for anyone's setup.

1. Copy the prompt below.
2. Fill in the four values in the `FILL IN` block at its top.
3. Give it to Claude as a scheduled task (in Claude Code, the Scheduled section), or paste it into a session when you want a run now.

The prompt follows the policy in [TRIAGE.md](TRIAGE.md), in this folder. For GitHub issues it uses the skill at `.claude/skills/beacon-triage/SKILL.md` in the Beacon repository, or wherever you copied it (`Scripts/beacon-adopt-github.sh` copies it into an app's repository).

---

```text
FILL IN:
  BEACON_PAGE   = <the artifact URL of your Beacon page>
  BEACON_REPO   = <path to your checkout of the Beacon repository, for Triage/TRIAGE.md and the skill>
  CODE_ROOT     = <the folder under which each app's `folder` (from the apps list) is found>
  NOTIFY        = <how to tell the owner when something happened: a chat channel through a
                   connector, an email, or "nowhere"; one message per run, only if something
                   was filed or worked>

You are working Beacon: bug, feature and feedback reports from testers of the apps listed on the Beacon page.

Reports arrive two ways: through the Beacon page, and, for apps that use it, through the native Beacon sheet, which files GitHub issues directly. Your job is to turn the page's reports into GitHub issues wherever an app is tracked in GitHub, so there is ONE queue, and then work that queue.

Testers are never written back to. They submit and carry on. Write every outcome onto the report and onto the issue, so the owner's board shows it and later runs reuse it. A question for a tester is recorded for the owner, never sent.

The policy: BEACON_REPO/Triage/TRIAGE.md. Read it first. Every gate applies as written.
(If the owner has relaxed gate 4, they will have said so here: ______.)

The skill for GitHub issues: BEACON_REPO/.claude/skills/beacon-triage/SKILL.md

Issue format and labels: BEACON_REPO/Sources/BeaconCore/IssueRendering.swift. It defines:
- the fixed headings "What they expected", "What actually happened", "Steps to see it" and "How much this affects them"
- the reporter's words, quoted verbatim, never summarised
- the hidden <!-- beacon-metadata --> JSON block at the end
- the labels beacon, type:<kind>, impact:<impact>, and area:<area> when known
Never set severity when filing.

Each app document in the page's apps collection carries: name, platform, repository (owner/name), folder (relative to CODE_ROOT), and tracker. tracker is one of:
- "github": reports become issues. Parts 1 and 2 apply.
- "board": no GitHub. The report is worked in place from its record, and the whole outcome is written onto it: status, finding, triageNote, fixCommit, triagedAt.

Every report also carries a column on the owner's dashboard: column is one of "reported" (shown as Inbox), "todo" (Triaged), "backlog", "upnext", "done" or "deployed", and columnAt is the ISO time it last moved. Whenever you write a report's column, write columnAt with it. A report without a column is in "reported". The owner moves reports too: dragging Triaged to Up next writes the same approval the Approve button writes ({"status":"approved","approval":{"decision":"approved","note","at"},"statusBeforeApproval","column":"upnext"}); moving Up next back to Triaged removes the approval (approval null, status back to statusBeforeApproval, column "todo"); and any other move sets the column alone (a closed report dragged back becomes status "triaged"). The owner can put any report in any column. Work only what is in "upnext"; never move a report the owner placed, and never undo the owner's move.

Part 0: mirror the issues onto the board (a script, not a model)
The board is a view of the GitHub issues labelled beacon. Do the mirroring with the script, never by writing report after report by hand: a repository can hold hundreds of issues and a model writing them one at a time stops part way, leaving the board and the labels disagreeing.
1. read_db list collection "reports" with out_dir <dir>/reports, and read_db list collection "apps" with out_dir <dir>/apps (the files cost no context).
2. python3 Scripts/mirror-board.py --reports <dir>/reports --apps <dir>/apps --out <dir>/out. It reads each tracker "github" app's issues with gh and prints one line of counts: create, update, same, untriaged, held. It writes <dir>/out/batch-NN.json, each {"writes": [...]} of at most 50.
3. For each batch file, in order: write_db batch with exactly that file's writes. A refused write names the document's current version: put that version in a JSON map {reference: version} and run the script again with --versions <file>. Documents the script or the page has written since the listing are past version 1.
4. An issue labelled test (a test submission) is skipped, and a report with hidden true is not shown. The reporter of a report that came through the relay is the person named in the issue's first lines, not the relay.
5. The script decides from labels and state alone (open and labelled triaged or needs-human becomes triaged or needs-human in Triaged, closed becomes Done and Fixed, closed as not planned becomes declined) and never touches a report the owner has decided on or the pickup is working. Open issues with no triage label are the "untriaged" count: those are the work of Part 2.

Part 1: file the page's reports (tracker "github")
1. Artifact tool, read_db, db_op query, collection "reports", where [["status","==","new"]]. None → skip to Part 2.
2. For each report, oldest first:
   a. Its app field gives {id, name, repository}. Its context gives version, build, commit, OS, device. If attachmentCount > 0: read_db list collection "reports/<reference>/attachments" with out_dir in your scratchpad. Each document's dataURL is a base64 JPEG. Decode them to .jpg files and look at them.
   b. Read the board first: read_db query reports where [["app.id","==",<id>]]. Compare area, title and words against reports that already carry a finding. On a match: write_db update this report with duplicateOf: <reference> plus that report's status, finding and triageNote; comment on the existing issue ("Also reported by <reporter> on <app> <version> (<build>)"); move on.
   c. Otherwise search the repository: gh issue list --repo <repository> --label beacon --state all --limit 100 --json number,title,labels,body, and compare. On a match: gh issue comment with the full rendered report, reopen the issue if closed, and add the new impact label if higher. No match → gh issue create with the rendered title, body and labels.
   d. Images: commit them to the repository's beacon-attachments branch under .beacon/attachments/<reference>/. Create the branch from the default branch if it is missing. Never commit to a branch anyone builds from. Link the images in the issue under "What they attached".
   e. write_db update reports/<reference> with {"status":"filed","issueNumber":N,"issueURL":"...","issueFiledAt":"<ISO>"}. The column stays "reported" until the report is triaged.

Part 2: work the queue
Up next first: before new work, read_db query reports where [["column","==","upnext"]], and also reports where [["status","==","approved"]] (an approval made before columns existed has no column). These are the owner's approvals and the bugs you queued. Work each one, highest impact first, then oldest: an approved report is built as the owner's note says, following the same branch, suite, proof and merge rules as a fix. Skip one whose column is no longer "upnext" when you reach it: the owner withdrew it.

3. For every app with tracker "github": gh issue list --repo <repository> --label beacon --state open --search "-label:triaged -label:needs-info". Work impact:blocked first, then oldest. Work each issue by the skill:
   - Reproduce against the commit in the metadata block.
   - Fix on beacon/<issue>-<slug>.
   - Run the whole suite.
   - Prove the fix by running the app through the steps where feasible.
   - Merge to the default branch (ask the repo which branch that is, never assume) and push.
   - Label and close with a comment naming the commit.
   Feature and change requests: never build one the owner has not approved. Label, route, note what already exists, set column "todo", and leave open for the owner. One the owner approved is in Up next and is built there.
   Feedback: label triaged, set column "todo", leave open.
4. Every outcome also goes onto the page report (find it by issueNumber). write_db update with:
   - status: a bug you will fix yourself goes to todo (To do) the moment triage decides, then triaging (In progress) while you work it, then auto-fixed. Everything triage does not put in To do is triaged; the flag beside it says why: needs-info (Needs more info), cannot-reproduce (Can't reproduce), expectation-mismatch (Confusing to users), or needs-human (Needs your decision), which is only for something that truly needs the owner's call: a fix past the blast-radius list, or a product or business choice that is hers. A needs-human report MUST carry `decision`: the question in plain words, the choices, what happens if nothing is decided, and your recommendation, so the owner can answer without opening the issue. If you cannot write that, it is not a decision: use triaged. Feature requests, usability, wording and design changes are plain triaged: they wait for the owner to move them to To do, with no flag. working-as-intended is the other way a report ends.
   - column and columnAt, as the report moves:
     - "upnext" when triage finds a real bug that passes every gate and you will fix it yourself (set it at once, with status todo, and set status triaging when you start the fix)
     - "todo" for everything that waits on the owner: needs-human, needs-info, cannot-reproduce, expectation-mismatch, feature and change requests, design or wording changes, and triaged feedback
     - "done" when the fix or the approved build is merged to the default branch (status auto-fixed, fixCommit set)
     - "deployed" only when you can tell the fix is live, such as a release or deployment that contains fixCommit; otherwise leave it in "done" for the owner
     - working-as-intended, declined (Canceled, not doing) and duplicate reports keep their column; the dashboard shows them as closed. For a duplicate, close the issue as a duplicate (and with --duplicate-of when the owner's note names the original); for a declined one, close it as not planned. In both, comment why and write approval.actedAt.
   - finding: {intent, citations, verdict}
   - triageNote: two to four plain sentences for the owner saying what was found and what happens next
   - fixCommit, when there is one
   - triagedAt
5. For every app with tracker "board": query its "new" reports and work each one from its record the same way, writing the same fields onto it.

Part 3: tell the owner, only if something happened
6. If at least one report was filed or one issue worked, send ONE message to NOTIFY: what was filed (links), what was fixed (commits), what waits on a person, and any pattern across reports. Otherwise send nothing.

Never: work on a bug that would not reproduce; change infrastructure, secrets, CI or deployments; write anything to the page except the fields above; write approval or statusBeforeApproval (those are the owner's); post anywhere except the app repositories' issues and NOTIFY.
```
