---
name: beacon-triage
description: >
  Triage Beacon feedback reports on a GitHub repository — the bug, feature
  and feedback issues filed from inside an app by the Beacon SDK. Use when
  asked to "triage the reports", "go through the beacon issues", "work the
  bug queue", "triage feedback", or when a scheduled run fires. Reads every
  open issue labelled `beacon` that isn't yet `triaged`, checks each one is
  complete, checks it against what the product is actually supposed to do,
  reproduces it, fixes and merges only the ones that meet the simple bar,
  and leaves everything else labelled and explained.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, WebFetch
---

# Triaging Beacon reports

Work the queue one issue at a time, all the way through, before starting
the next. A half-triaged issue is worse than an untouched one because the
labels lie about what has been checked.

The policy is `Triage/TRIAGE.md` in the Beacon repository, or wherever the
adopting app copied it. **Read it before starting.** This skill is how to
run it; that file is what the rules are, and it wins wherever the two seem
to differ.

## Before anything

```bash
gh issue list --repo <owner/repo> --label beacon --state open \
  --search "-label:triaged -label:needs-info" \
  --json number,title,labels,createdAt,body --limit 50
```

Order the queue by `impact:blocked` first, then oldest first. Somebody who
can't work waits the least.

Read `BeaconIndex.json` in the app's repository once, at the start. It maps
each `area:` label to real source paths, and it is how you find the code an
issue is about without guessing.

Each issue has a hidden `<!-- beacon-metadata ... -->` block at the bottom.
Parse it. It carries the commit the report came from, the reproducibility
answer, the step count, and the app version — all of which change what you
do next.

## For each issue

### 1. Complete?

Check the three fixed headings carry real answers. Missing or empty →
`needs-info`, comment with at most two specific questions, move on.

Never ask for anything already in the issue. The version, the settings, the
folder layout and the log are all in the collapsed sections.

### 2. Actually a bug?

**Find what the product is supposed to do before you look at the code that
does it.** Search the paths from the `area:` label for acceptance criteria,
specs, the user-facing copy, and the existing tests. Quote what you find,
with a path and a line number, in your triage comment. "I checked" is not a
finding.

Then compare the product's intended behaviour, the reporter's expectation,
and what happened:

- **Intended ≠ what happened** → a real bug. Go to 3.
- **Intended = what happened, and the reporter expected the same** → they
  were describing something else. Ask.
- **Intended = what happened, but the reporter expected something else** →
  **expectation mismatch.** Label `expectation-mismatch`, open a *separate*
  issue about the communication gap, link them, and reply in the reporter's
  own terms — never "working as intended" alone.

This gate exists because a fix that chases a reporter's expectation without
checking the product's intent changes the product by accident.

### 3. Reproducible?

**No reproduction, no work.** Not a preference — a hard stop.

```bash
git checkout <commit from the metadata block>
```

Write a check that fails because of the bug. A test where a test can see
it; a real run of the app where only the screen can. Then run it and watch
it fail.

Where the bug needs data to exist first, seed it — Beacon ships
`BeaconSeed`, which copies a folder over the app's data directory when
`BEACON_SEED_DIRECTORY` and `BEACON_SEED_ENABLE=1` are both set. Keep a seed
per common shape under `Triage/seeds/`.

Three attempts, varying only what the report leaves ambiguous. Still
nothing → `cannot-reproduce`, comment with exactly what was tried (build,
steps as run, what happened instead), ask the one best question, stop.

### 4. Simple?

Every line of the simple bar in `TRIAGE.md` must be true. Check them
explicitly and write the check into the issue comment — size, blast
radius, evidence, certainty. One false → `needs-human` with a written
diagnosis, and stop.

Feature requests are never implemented here. Label, route, note what
already exists, leave for a person.

### 5. Fix, prove, merge

Branch as `beacon/<issue-number>-<short-slug>`. Make the smallest change
that makes the failing check pass.

Then **run the app and walk the reporter's steps.** Tests passing is not
proof that the thing they reported stopped happening. Attach to the issue:
the check failing before and passing after, a screenshot at the step that
used to be wrong, and the steps as you ran them.

Merge, comment naming the commit, thank the reporter by name, close, label
`auto-fixed`.

If you cannot produce that proof, open a pull request instead of merging,
label `needs-human`, and say what's missing.

### 6. Always

Set severity per the table in `TRIAGE.md` — it is your judgement about the
product, not the reporter's about themselves. Add `triaged`. Reply to the
reporter in plain words, whatever the outcome; somebody who took ten
minutes to write a report is owed a sentence back.

## When the queue is done

Post one summary: how many were triaged, how many fixed, how many are
waiting on a person, how many on the reporter. Then call out anything the
queue itself is saying — several reports on one area, a pile of
`impact:blocked` on something rated low, the same expectation mismatch
twice. That pattern is usually worth more than any single fix, and nobody
sees it except whoever just read the whole queue.

## Never

- Work on a bug that would not reproduce.
- Change behaviour to match an expectation without checking the intent.
- Implement a feature request.
- Merge without having run the app through the reporter's own steps.
- Touch schemas, credentials, payments, networking, concurrency, public
  APIs, CI, or signing (the blast-radius list) unattended.
- Close anything without a reply the reporter can understand.
