# How Beacon reports get triaged

This is the policy half of Beacon. The app files reports; this decides what
happens to them. It is written to be followed by an agent working
unattended, so every rule is a rule and not a preference — where a judgement
call is unavoidable it is named as one, with the safe answer written down.

The point of all of it: a tester should get their problem fixed without
waiting for a person. That only works if the things an agent does without a
person are things it cannot get badly wrong.

---

## The order of work

Every issue labelled `beacon` goes through these gates **in order**. A gate
that fails stops the issue where it is; it never falls through to the next.

1. **Is it complete?** → otherwise `needs-info`
2. **Is it actually a bug?** → otherwise `working-as-intended` /
   `expectation-mismatch`
3. **Can it be reproduced?** → otherwise `cannot-reproduce`
4. **Is it simple?** → otherwise `needs-human`
5. **Fix it, prove it, merge it.**

---

## Gate 1 — Is it complete?

Read the three fixed headings. If any of "What they expected", "What
actually happened", or "Steps to see it" is missing or says nothing, add
`needs-info`, comment with the specific question, and stop.

Ask at most two questions and ask them as questions. Never ask for
something the report already contains — the app details, the settings and
the folder layout are all in the collapsed sections, and asking for them
tells the reporter nobody read their report.

## Gate 2 — Is it actually a bug?

**Never start from the reporter's "expected". Start from what the product
is supposed to do**, and find that in the source before touching anything:

- acceptance criteria or specs for the area (`area:` label → the source
  paths in `BeaconIndex.json`)
- the user-facing copy the app actually shows
- the tests that already exist for that behaviour
- the plan or design document that introduced it

Write down which of those you used. "I checked" is not a finding; "the
acceptance criterion at *path:line* says X" is.

Then compare three things:

| The product's intended behaviour | The reporter's expectation | What happened | Verdict |
|---|---|---|---|
| X | X | not X | **A real bug.** Go to gate 3. |
| X | X | X | **Working as intended.** Label `working-as-intended`, explain in the reporter's own terms, close. |
| X | Y (≠ X), and what happened was X | **The product is not explaining itself.** See below. |

### The expectation mismatch — this is a finding, not a rejection

When the app did exactly what it was designed to do and the reporter
expected something else, **that is a defect in the product's
communication**, and it is often more valuable than the bug they thought
they were reporting. So:

1. Label the issue `expectation-mismatch` and leave it open.
2. Open a **separate** issue labelled `beacon`, `type:bug`,
   `expectation-mismatch`, and the same `area:`, describing the gap: what
   the product does, what this person expected, and what they were looking
   at when they formed that expectation.
3. Link the two.
4. Reply to the reporter saying what the app is actually doing and why —
   never "working as intended" on its own, which reads as "you're wrong".

Do not fix a `expectation-mismatch` issue by changing the behaviour. Wording,
labels and empty states are the fix, and those are a person's call unless
they are covered by gate 4's simple-change list.

## Gate 3 — Can it be reproduced?

**An agent may not work on a bug it cannot reproduce.** No exceptions, and
no "the fix looks obvious" override — a fix for a bug you never saw is a
change with no evidence behind it.

Reproducing means: the steps from the issue, run against the build the
report came from (`commit` in the metadata block, or the version and build
number), producing a **failing check that passes once the bug is fixed.**
Usually that is a test; where the failure is only visible on screen it is a
UI run with a screenshot of the wrong state. A description of the failure is
not a reproduction.

Try up to **three** times, varying only what the report leaves ambiguous.
If it still won't reproduce:

- Label `cannot-reproduce`.
- Comment with exactly what was tried — the build, the steps as run, and
  what happened instead. A reporter who reads "couldn't reproduce" with no
  detail concludes nobody tried.
- Ask the one question most likely to close the gap.
- Stop. Do not investigate further, and do not change code.

## Gate 4 — Is it simple?

A fix may be made and merged without a person **only when every line below
is true**. One false means `needs-human`.

**Size**
- Three files or fewer changed.
- Forty changed lines or fewer, not counting tests.
- No new dependency, and no dependency version change.

**Blast radius** — the change touches none of:
- data schemas, migrations, or anything that writes persistent user data
- authentication, credentials, keychain, tokens, or permissions
- payments, subscriptions, or pricing
- networking or transport code
- concurrency primitives — locks, actors, task groups, isolation attributes
- any public API of a shipped library
- build configuration, CI, signing, or entitlements
- generated or vendored files

**Evidence**
- A failing check existed before the change and passes after it (gate 3).
- The whole test suite passes.
- The reproduction steps, re-run against the built app, no longer produce
  the reported behaviour (gate 5).

**Certainty**
- The cause is understood and can be stated in one sentence. "This makes
  the symptom go away" is not understanding, and is `needs-human`.

Everything else — anything ambiguous, anything where the right behaviour is
a product decision, anything touching design or copy that isn't a plain
typo — gets `needs-human`, a written diagnosis in the issue, and stops.

**Feature requests are never auto-implemented.** Triage them: label, route
to an area, note whether the codebase already has most of what's needed,
and leave them for a person. Requirement of the system, not a limitation.

## Gate 5 — Prove it, then merge

A fix is not done because the tests pass. **Run the app and walk the
reporter's steps.** Attach to the issue:

- the failing check before, passing after
- a screenshot of the app at the step that used to be wrong
- the exact steps as run

Then merge, comment on the issue naming the commit, thank the reporter by
name, and close. Label `auto-fixed`.

If any of that can't be produced, the fix opens a pull request instead of
merging, labelled `needs-human`, with what's missing written down.

---

## Setting severity

Severity is set here, never by the app. The reporter gave `impact:` — how
much it costs *them*. Severity is how much it costs *everyone*.

| Severity | Means |
|---|---|
| `severity:critical` | Data loss, a security problem, or the app is unusable for anyone who hits it. |
| `severity:high` | A main path is broken with no workaround. |
| `severity:medium` | Broken with a workaround, or a secondary path. |
| `severity:low` | Cosmetic, rare, or only under unusual settings. |

Reach for one higher when: `impact:blocked` **and** `reproducibility:
every-time`; or more than one person has reported it; or it involves
anything under "Blast radius" above.

Impact and severity disagreeing is normal and worth noticing — a pile of
`impact:blocked` on a `severity:low` issue usually means the workaround is
not as findable as somebody thought.

## The labels

Set by the app: `beacon`, `type:bug|feature-request|feedback`,
`impact:blocked|slowed|irritating|noticed`, `area:<id>`.

Set by triage: `severity:*`, `needs-info`, `cannot-reproduce`,
`expectation-mismatch`, `working-as-intended`, `auto-fixed`, `needs-human`,
`triaged`.

Create them once per repository with `Scripts/beacon-labels.sh`.

## What triage never does

- Work on a bug it could not reproduce.
- Change behaviour to match a reporter's expectation without checking what
  the product is supposed to do.
- Implement a feature request.
- Close an issue as "working as intended" without filing the
  expectation-mismatch issue and replying in plain words.
- Touch anything on the blast-radius list.
- Merge without having run the app through the reporter's own steps.
