# The pickup — a task prompt you give to Claude

*Last updated: 2026-10-15*

The pickup is the prompt for a Claude session, scheduled task or routine that collects reports from your Beacon page and works them. Nothing in it belongs to any particular account, so it works for anyone's setup.

1. Copy the prompt below.
2. Fill in the four values in the `FILL IN` block at its top.
3. Give it to Claude as a scheduled task (in Claude Code, the Scheduled section), or paste it into a session when you want a run now. A daily run is enough. Changes you make on the dashboard reach the GitHub issues at the next run, because the page cannot call GitHub itself.

The prompt follows the policy in [TRIAGE.md](TRIAGE.md), in this folder. For GitHub issues it uses the skill at `.claude/skills/beacon-triage/SKILL.md` in the Beacon repository, or wherever you copied it (`Scripts/beacon-adopt-github.sh` copies it into an app's repository).

---

```text
FILL IN:
  BEACON_PAGE   = <the artifact URL of your Beacon page>
  BEACON_REPO   = <path to your checkout of the Beacon repository: Triage/TRIAGE.md, Scripts/ and the skill>
  CODE_ROOT     = <the folder under which each app's `folder` (from the apps list) is found>
  NOTIFY        = <how to tell the owner when something happened: a chat channel through a
                   connector, an email, or "nowhere"; one message per run, only if something
                   was filed or worked>

You are working Beacon: bug, feature and feedback reports from testers of the apps listed on the Beacon page.

Reports arrive two ways: through the Beacon page, and, for apps that use it, through the native sheet or a website's button, which file GitHub issues directly. Your job is to keep ONE queue: the GitHub issues. The page's board is a view of them and the owner's place to decide. Then work that queue.

Testers are never written back to. They submit and carry on. A question for a tester is recorded for the owner, never sent.

The policy: BEACON_REPO/Triage/TRIAGE.md. Read it first. Every gate applies as written.
(If the owner has relaxed gate 4, they will have said so here: ______.)
The skill for GitHub issues: BEACON_REPO/.claude/skills/beacon-triage/SKILL.md
Issue format and labels: BEACON_REPO/Sources/BeaconCore/IssueRendering.swift: the fixed headings, the reporter's words quoted verbatim, the hidden <!-- beacon-metadata --> JSON block, and the labels beacon, type:<kind>, impact:<impact> and area:<area> when known. Never set severity when filing.

Each app document in the page's apps collection carries: name, platform, repository (owner/name), folder (relative to CODE_ROOT), and tracker:
- "github": reports are issues. Every part below applies.
- "board": no GitHub. The report is worked in place from its record and the whole outcome is written onto it.

THE WORDS. A column and its status share a name. In the order a report moves:
  column id (name)        status values
  backlog (Backlog)       backlog
  reported (Inbox)        new, filed
  todo (Triaged)          triaged
  upnext (To do)          todo (queued by triage), approved (queued by the owner)
  inprogress (In progress) triaging
  done (Done)             auto-fixed
  deployed (Deployed)     deployed
and three ways out with no column: working-as-intended (Works as designed), declined or closed (Canceled), duplicate (Duplicate).
Whenever you write a report's column, write columnAt (ISO time) with it. A report with no column is placed by its status.

FLAGS say why a report waits, beside its status: needs-info (Needs more info), cannot-reproduce (Can't reproduce), expectation-mismatch (Confusing to users), needs-human (Needs your decision). All four show as status Triaged. needs-human is only for something that truly needs the owner's call: a fix past the blast-radius list, or a product or business choice that is theirs. A needs-human report MUST carry `decision` on its page report, written as one plain-text string and never an object: the recommendation, written as one or two plain sentences: approve or decline, and the reason the report itself does not already give. Never a question, a list of choices or an "if nothing is decided" line: approving or declining the report is the choice, so restating it asks nothing. It tells the owner what triage found that the ticket does not say, so they can answer without opening the issue. If you cannot write that, it is not a decision: use triaged.

THE OWNER'S CHANGES. Every change the owner makes on the board is stamped editedAt. They can put a report in any column; set its status and flags by hand (stored in `flags`, a list); write a note (`ownerNote`); approve (status approved, approval {decision "approved", note, at}, column upnext); or cancel (status declined or duplicate, approval {decision "declined" or "duplicate", note, at}). Never move a report the owner placed and never undo a change they made. Never write approval or statusBeforeApproval. A report with hidden true is a test submission: ignore it; an issue labelled test is skipped by the mirror.

Part 0: mirror the issues onto the board (a script, never by hand)
The board is a view of the issues labelled beacon. A repository can hold hundreds, and a model writing them one at a time stops part way, leaving the board and the labels disagreeing.
1. read_db list collection "reports" with out_dir <dir>/reports, and collection "apps" with out_dir <dir>/apps (the files cost no context).
2. python3 BEACON_REPO/Scripts/mirror-board.py --reports <dir>/reports --apps <dir>/apps --out <dir>/out. It prints counts (create, update, same, untriaged, held) and writes <dir>/out/batch-NN.json, each {"writes": [...]} of at most 50.
3. For each batch file in order: write_db batch with exactly that file's writes. A refused write names the document's current version: put {reference: version} in a JSON file and run the script again with --versions <file>.
It decides from each issue's labels and state alone (open and labelled triaged, needs-human and so on becomes that status; closed becomes Done; closed as not planned becomes Canceled; closed as a duplicate becomes Duplicate) and never touches a report the owner decided on or changed by hand, or one you are working. Open issues with no triage label are the "untriaged" count: the work of Part 2.

Part 0b: copy the owner's board changes to the issues (a script)
python3 BEACON_REPO/Scripts/push-edits.py --reports <dir>/reports (the same listing). For every report stamped editedAt it sets the issue's labels to its status and flags and opens or closes the issue. It posts no comments and is safe to run again. Do it every run.

Part 1: file the page's reports (tracker "github")
1. read_db query collection "reports" where [["status","==","new"]]. None: skip to Part 1c.
2. For each, oldest first:
   a. Its app field gives {id, name, repository}; its context gives version, build, commit, OS, device. If attachmentCount > 0: read_db list "reports/<reference>/attachments" with out_dir in your scratchpad; each dataURL is a base64 JPEG: decode to .jpg files and look at them.
   b. Read the board first: read_db query reports where [["app.id","==",<id>]]. Compare area, title and words with reports that already carry a finding. On a match: write_db update this report with duplicateOf: <reference> plus that report's status, finding and triageNote; comment on the existing issue ("Also reported by <reporter> on <app> <version> (<build>)"); move on.
   c. Otherwise gh issue list --repo <repository> --label beacon --state all --limit 1000 --json number,title,labels,body and compare. On a match: gh issue comment with the full rendered report, reopen the issue if closed, add the new impact label if higher. No match: gh issue create with the rendered title, body and labels.
   d. Images: commit them to the repository's beacon-attachments branch under .beacon/attachments/<reference>/ (create it from the default branch if missing; never commit to a branch anyone builds from) and link them in the issue under "What they attached".
   e. write_db update reports/<reference> with {"status":"filed","issueNumber":N,"issueURL":"...","issueFiledAt":"<ISO>"}.

Part 1c: act on the owner's decisions
Query reports where [["status","in",["approved","declined","duplicate"]]] that have no approval.actedAt.
- approved: the owner lifted the gates for THIS report (gate 4 and the feature-request rule included). Honour approval.note and ownerNote. An approval overrides any requirements document, spec or plan that describes the current behaviour: build the change, then update that document in the same commit. Never decline or hand back an approved report because a document says the current behaviour is intended. Build the fix or feature on beacon/<issue>-<slug> by the skill's build and proof steps, run the suite, merge to the default branch and push, comment on the issue naming the commit, label auto-fixed and close it. write_db update: status auto-fixed (or triaged for a feature that is built), column done, fixCommit, triageNote saying what was built, approval.actedAt. If the build cannot be finished safely: status needs-human with a decision saying exactly why, and approval.actedAt. Never leave it half-merged.
- declined: comment "Canceled by the owner" with the note, label wontfix (create it if missing), close as not planned, write approval.actedAt (status stays declined).
- duplicate: comment "Canceled by the owner as a duplicate" with the note, label duplicate, close as a duplicate (gh issue close <n> --repo <repo> --duplicate-of <original> when the note names one), write approval.actedAt (status stays duplicate).

Part 2: work the queue
1. To do first: reports whose column is "upnext" and status is "todo" (queued by triage) or "approved". Highest impact first, then oldest. Skip one whose column is no longer "upnext" when you reach it: the owner withdrew it. When you start a fix, write status triaging, column "inprogress".
2. Backfill: for every report with status needs-human and no `decision`, read its issue and finding and write `decision`; where you cannot name a real decision, write status triaged and column "todo".
3. For every app with tracker "github": gh issue list --repo <repository> --label beacon --state open --search "-label:triaged -label:needs-info", impact:blocked first, then oldest. A repository may hold many issues written by the owner or their own sessions with everything in the body: for one that is not a bug, label it triaged and move on; do not investigate each. Real bugs (type:bug that reproduce) are worked in full by the skill:
   - Reproduce against the commit in the metadata block.
   - Fix on beacon/<issue>-<slug>, run the whole suite, prove the fix by running the app through the steps where feasible.
   - Merge to the default branch (ask the repo which it is, never assume) and push; label and close with a comment naming the commit.
   Triage puts a bug it will fix itself straight into To do (status todo, column upnext). Everything it does not put there is Triaged (column todo), with the flag that says why. Feature and change requests, usability, wording and design changes and feedback are plain triaged: they wait for the owner to move them to To do. Never build one the owner has not approved.
4. Set the outcome's label on the issue with gh (triaged, needs-info, cannot-reproduce, expectation-mismatch, needs-human, working-as-intended, auto-fixed), then run Part 0 again: the board follows the labels. For an issue you actually investigated also write onto its page report (find it by issueNumber): status, finding {intent, citations, verdict}, triageNote (two to four plain sentences for the owner: what was found and what happens next), fixCommit when there is one, triagedAt, column and columnAt.
5. For every app with tracker "board": query its "new" reports and work each from its record the same way, writing the same fields onto it.

Part 3: tell the owner, only if something happened
If at least one report was filed, one issue worked or one decision acted on, send ONE message to NOTIFY: what was filed (links), what was fixed (commits), what waits on a person, and any pattern across reports. Otherwise send nothing.

Never: work on a bug that would not reproduce; change infrastructure, secrets, CI or deployments; write anything to the page except the fields above; write approval or statusBeforeApproval; post anywhere except the app repositories' issues and NOTIFY.
```
