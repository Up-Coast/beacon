# What happens to a report

*Last updated: 2026-09-07*

Every report is worked by a Claude session against a written policy. This page is that
policy in plain words, so you know what will and will not happen to a report without you.

The point of all of it: a tester should get their problem fixed without waiting for a
person. That only works if the things a session does without a person are things it cannot
get badly wrong.

## The gates, in order

A report goes through these one after another. A gate that fails stops the report there; it
never falls through to the next.

### 1. Is it complete?

The three answers a bug needs — what was expected, what happened, the steps — must say
something. The page already refuses empty ones, so this mostly catches subtler gaps. A
report that cannot be worked is marked as needing more, with the specific question noted
on the board. The tester is not chased.

### 2. Is it actually a bug?

The session never starts from the tester's "expected". It starts from **what the product
is supposed to do**, and finds that in your source before touching anything: acceptance
criteria, the copy the app shows, the tests that already exist, the plan that introduced
the behaviour. It writes down which of those it used, with a path and a line. "I checked"
is not a finding.

Then it compares three things: what the product intends, what the tester expected, and
what happened.

- Intended one thing, got another: **a real bug.** On to gate 3.
- Intended, expected and got the same thing: the tester was describing something else.
  Noted, not fixed.
- The app did exactly what it was designed to do, but the tester expected something
  else: **the app isn't explaining itself.** This is treated as a finding, not a rejection.
  The report is kept, a separate one is opened about the gap in the product's
  communication, and the two are linked. Behaviour is never changed to match a tester's
  expectation; wording, labels and empty states are the fix, and those are your call.

### 3. Can it be reproduced?

**A session may not work on a bug it cannot reproduce.** No exceptions, and no "the fix
looks obvious" override.

Reproducing means running the tester's steps against the build they had — the commit the
app baked into the report — and producing a check that fails because of the bug and passes
once it is fixed. A test where a test can see it; a run of the app with a screenshot of the
wrong state where only the screen can.

Three attempts, varying only what the report leaves ambiguous. If it still won't happen,
the report is marked as not reproduced, with exactly what was tried written on the board,
and the session stops. It does not investigate further and does not change code.

### 4. Is it safe to fix unattended?

A fix is made without a person only when it stays clear of everything on this list:

- data schemas, migrations, or anything that writes persistent user data
- authentication, credentials, keychain, tokens, or permissions
- payments, subscriptions, or pricing
- networking or transport code
- concurrency primitives
- any public API of a shipped library
- build configuration, CI, signing, or entitlements
- generated or vendored files

and only when the cause can be stated in one sentence. "This makes the symptom go away" is
not understanding. Anything on that list, anything ambiguous, and anything where the right
behaviour is a product decision, gets a written diagnosis on the board and the status
"needs a person".

### 5. Fix it, prove it, merge it

A fix is not done because the tests pass. The session runs the app and walks the tester's
own steps, and records the failing check before and the passing one after, a screenshot at
the step that used to be wrong, and the exact steps as run. Then it merges, links the
commit on the board and the issue, and marks the report fixed. If it cannot produce that
proof, it opens a pull request instead of merging and marks the report as needing a person.

## Feature requests and feedback

A feature request is never built unattended unless the code already has most of it, and
then the note says so. Otherwise it is labelled, routed to the part of the app it belongs
to, and left for you with a note on what already exists.

Feedback is read, labelled and kept. Patterns across reports — several about one area, a
pile of "I can't work" on something rated low — are called out in the summary you receive,
because nobody sees them except whoever read the whole queue.

## Severity

Testers say how much a problem costs *them*. Severity — how much it costs *everyone* — is
set during triage: critical for data loss, security, or the app being unusable; high for a
main path broken with no workaround; medium for broken with a workaround or a secondary
path; low for cosmetic or rare. It is raised one step when the tester is blocked and it
happens every time, or when more than one person has reported it.

## What a session never does

- Works on a bug it could not reproduce.
- Changes behaviour to match an expectation without checking what the product intends.
- Implements a feature request that isn't already mostly there.
- Touches anything on the list in gate 4.
- Merges without having run the app through the tester's own steps.
- Writes to a tester.
