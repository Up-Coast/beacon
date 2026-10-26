# How Beacon reports get triaged

*Last updated: 2026-10-25*

This is Beacon's triage policy: the app files reports, and this document decides what happens to them. An agent follows it unattended, so every rule is a rule, not a preference. Where a judgement call cannot be avoided, the rule names it and states the safe answer.

The goal is that a tester gets their problem fixed without waiting for a person. That only works if everything an agent does without a person is something it cannot get badly wrong.

---

## The order of work

Every issue labelled `beacon` goes through these gates **in order**. When a gate fails, the issue stops at that gate. It never falls through to the next one.

Set the report's status to `triaging` when work on it starts, so the owner's dashboard shows what is being looked at now.

Each report also has a column on the dashboard, `column`, with `columnAt` written beside it whenever it changes. A report waiting on the owner (every gate that stops with a label below, and every feature request, change request and piece of feedback) goes to `todo`. A bug that passes gates 1 to 4 goes to `upnext` when its fix starts. A fix merged by gate 5 goes to `done`. `deployed` is for a fix known to be live. The owner moves reports from `todo` to `upnext` by approving them. Everything in `upnext` is built by [the worker](WORKER.md), through gate 5; the pickup never builds. [The pickup prompt](PICKUP.md) has the exact writes.

1. **Is it complete?** If not: `needs-info`.
2. **Is it actually a bug?** If not: `working-as-intended` or `expectation-mismatch`.
3. **Can it be reproduced?** If not: `cannot-reproduce`.
4. **Is the fix a product decision?** If so: `needs-human`, with the recommendation. Otherwise it goes to To do.
5. **Fix it, prove it, merge it.**

---

## Gate 1 — Is it complete?

Read the three fixed headings: "What they expected", "What actually happened" and "Steps to see it". If any of them is missing or says nothing:

1. Add `needs-info`.
2. Comment with the specific question the report leaves open, for the owner to decide whether to ask.
3. Stop.

Write at most two questions, and phrase them as questions. Never write to the tester: the comment is the record, not a message to them.

Never ask for something the report already contains. The app details, the settings and the folder layout are all in the collapsed sections. Asking for them tells the reporter nobody read their report.

## Gate 2 — Is it actually a bug?

**An approved report skips this gate.** When the owner has approved a report (status `approved`, or the report in To do by the owner's hand), the owner has already decided the behaviour should change. Build it. Do not compare it with a requirements document, spec or plan and do not close it as working as intended: those documents record what was built first, a ticket is newer, and software is built first and then iterated. If a document contradicts the ticket, the ticket wins; build the change and update the document in the same commit so they agree. Never decline, defer or hand back an approved report because a document says otherwise. The one exception is the owner's own `Waiting for human` flag: a report carrying it is left completely alone until the owner clears it.

**Never start from the reporter's "expected". Start from what the product is supposed to do.** Find that in the source before touching anything:

- acceptance criteria or specs for the area (the `area:` label maps to source paths in `BeaconIndex.json`)
- the user-facing copy the app actually shows
- the tests that already exist for that behaviour
- the plan or design document that introduced it

Write down which of these you used. "I checked" is not a finding. "The acceptance criterion at *path:line* says X" is.

Then compare three things:

| The product's intended behaviour | The reporter's expectation | What happened | Verdict |
|---|---|---|---|
| X | X | not X | **A real bug.** Go to gate 3. |
| X | X | X | **Working as intended.** The report describes something else. Label `working-as-intended`, write what the product does and why, close. |
| X | Y (≠ X), and what happened was X | **The product is not explaining itself.** See below. |

### The expectation mismatch — this is a finding, not a rejection

When the app did exactly what it was designed to do and the reporter expected something else, **that is a defect in how the product communicates**. It is often more valuable than the bug they thought they were reporting. So:

1. Label the issue `expectation-mismatch` and leave it open.
2. Open a **separate** issue labelled `beacon`, `type:bug`, `expectation-mismatch`, and the same `area:`. Describe the gap: what the product does, what this person expected, and what they were looking at when they formed that expectation.
3. Link the two issues.
4. Write on the issue what the app is actually doing and why. "Working as intended" on its own is never the whole comment: the finding is the gap, not the tester's mistake.

Do not fix an `expectation-mismatch` issue by changing the behaviour. The fix is wording, labels and empty states, and those are a person's call; it waits in To Triage for the owner.

## Gate 3 — Can it be reproduced?

**An agent may not work on a bug it cannot reproduce.** There are no exceptions, and no "the fix looks obvious" override. A fix for a bug nobody saw is a change with no evidence behind it.

Reproducing means running the steps from the issue against the build the report came from (`commit` in the metadata block, or the version and build number), and producing a **failing check that passes once the bug is fixed.** Usually that check is a test. Where the failure is only visible on screen, it is a UI run with a screenshot of the wrong state. A description of the failure is not a reproduction.

Try up to **three** times, varying only what the report leaves ambiguous. If it still does not reproduce:

- Label `cannot-reproduce`.
- Comment with exactly what was tried: the build, the steps as run, and what happened instead. A reporter who reads "couldn't reproduce" with no detail concludes nobody tried.
- Write the one question most likely to close the gap, for the owner to ask if they choose.
- Stop. Do not investigate further, and do not change code.

## Gate 4 — Is the fix a product decision?

A bug that passed gates 1 to 3 is real, reproduced and has a failing check. **It goes to To do and gets built.** Label it `triaged` and `todo`, write the finding and the reproduction onto the report, and the worker builds it through gate 5. That is the normal outcome of a bug, and it needs nobody's approval: the owner's standing decision is that bugs are fixed.

The size of the fix, the number of files, and the area it touches (data, authentication, payments, networking, concurrency, build configuration, anything) are never reasons to stop. Gate 5 is the safeguard: every fix is proven on the built app, the whole suite passes, and a fix that cannot be proven goes up as a pull request instead of a merge.

The one thing that stops a bug here is a **product decision**: the reporter and the source disagree about what the product should do, and nothing in the ticket, the owner's notes, the documents or the existing app settles it. Then the issue gets `needs-human`, a written diagnosis, and a `decision` on the report: which way triage recommends and why. "Let Claude fix this bug?" is never a decision. If the only question is whether to build the fix, the answer is yes, and the report goes to To do.

A bug whose cause is not yet understood still goes to To do: finding the cause is the worker's job, and it stops with Blocked if it cannot.

**A feature request or a change request is never implemented without the owner authorizing it.** That holds however small the request looks, and however much of it the codebase already has. Triage it: label it, route it to an area, note what already exists, and leave it open for the owner.

**Feedback is never implemented either.** Label it `triaged`, route it to an area, and leave it open.

## Gate 5 — Prove it, then merge

Passing tests do not make a fix done. **Run the app and walk the reporter's steps.** Attach to the issue:

- the failing check before, and the passing check after
- a screenshot of the app at the step that used to be wrong
- the exact steps as run

Then:

1. Merge.
2. Comment on the issue naming the commit.
3. Close the issue.
4. Label it `auto-fixed`.

If any of that cannot be produced, open a pull request instead of merging. Label it `needs-human` and write down what is missing.

---

## Setting severity

Severity is set here, never by the app. The reporter gave `impact:`, which is how much the problem costs *them*. Severity is how much it costs *everyone*.

| Severity | Means |
|---|---|
| `severity:critical` | Data loss, a security problem, or the app is unusable for anyone who hits it. |
| `severity:high` | A main path is broken with no workaround. |
| `severity:medium` | Broken with a workaround, or a secondary path. |
| `severity:low` | Cosmetic, rare, or only under unusual settings. |

Choose one level higher when any of these is true:

- `impact:blocked` **and** `reproducibility: every-time`
- more than one person has reported it
- it touches stored user data, authentication, payments or networking

Impact and severity often disagree, and the disagreement is worth noticing. Several `impact:blocked` reports on a `severity:low` issue usually mean the workaround is harder to find than somebody thought.

## Tasks only a person can do

Triage reads every ticket for work an agent is not allowed or able to do: a live purchase or refund, moving money, signing in or creating an account, entering a secret, using a physical device, or a legal or business sign-off. Such a ticket is triaged as usual, and it also gets the flag `Waiting for human` (the label `flag:waiting-for-human` on the issue). The flag marks the ticket as the owner's, so it can be moved to Backlog or To do without ticking anything, and the worker never starts it.

## The labels

Set by the app: `beacon`, `type:bug|feature-request|change-request|feedback`, `impact:blocked|slowed|irritating|noticed`, `area:<id>`.

Set by triage: `severity:*`, `needs-info`, `cannot-reproduce`, `expectation-mismatch`, `working-as-intended`, `auto-fixed`, `needs-human`, `triaged`.

`needs-human` is for a product or business choice only the owner can make, never for whether to fix a bug, and the report must say what the call is: write `decision` on the page report (the recommendation, written as one or two plain sentences: approve or decline, and the reason the report itself does not already give. Never a question, a list of choices or an "if nothing is decided" line: approving or declining the report is the choice, so restating it asks nothing.). If you cannot write it, it is not a decision: label `triaged` and leave it for the owner to move.

Create them once per repository with `Scripts/beacon-labels.sh`.

## What triage never does

- Work on a bug it could not reproduce.
- Change behaviour to match a reporter's expectation without checking what the product is supposed to do.
- Refuse, decline or hand back a report the owner approved because a requirements document, spec or plan says the current behaviour is intended. The approval is the product decision.
- Implement a feature request or a change request, or act on feedback, without the owner authorizing it.
- Close an issue as "working as intended" when the reporter expected something different, without first filing the expectation-mismatch issue.
- Write to a tester. Triage writes on the issue and on the dashboard, and never contacts the person who reported.
- Move a report the owner placed, or undo a move the owner made. Approving is the owner's.
- Stop a reproduced bug for approval. Only a product decision stops a bug, and the report must say what it is.
- Merge without having run the app through the reporter's own steps.
