# How it works

*Last updated: 2026-09-07*

A report's journey, from the button to a fix.

## 1. The app opens the page

`BeaconInboxButton` opens your Beacon page in the browser. The link carries what the machine
knows and the tester would otherwise have to type: app, version, build, commit, operating
system and its version, device model, language, time zone, appearance and text size, and
who is signed in. Because the link carries a version, the page locks the app choice; the
tester cannot file a Harbour report against the wrong app.

Open the page without a link and it still works: the tester picks the app from a list.

## 2. The tester writes the part only they know

Three kinds of report share one form:

- **Something's broken.** What actually happened, what they expected instead, and the
  steps that get there. All three are required, and the page refuses answers that are
  filled in but empty — "n/a", "it broke", "asdf" and the like. It also asks whether the
  problem happens again, because a bug that cannot be made to happen again cannot be
  worked on.
- **Something's missing.** What they want to be able to do, and why.
- **Something else.** Anything.

Every report asks how much this costs *them*, in their own words, from "I can't do what I
came to do" down to "I noticed it". Severity is decided later, by the people looking at
the whole product; the tester is only asked the thing only they can answer.

Images come along: screenshots, photos of the screen, or an image pasted straight in. Each
one is shrunk on the tester's own device before it leaves.

## 3. Send, and carry on

The report is stored, the tester gets a reference like `BN-8EA6C3`, and that is the end of
their part. Nobody writes back to them asking for more. If they notice something else, they
send that too.

## 4. A Claude session picks it up

The page rings a doorbell when a report lands: a Claude session watching the page is told
within about a minute. When no session is watching, a scheduled task checks the page on a
schedule and works whatever arrived. Either way, no person is in the loop.

The pickup does two things with each report:

- **Files it.** For an app tracked in GitHub, the report becomes an issue in that
  repository, in a fixed layout with the tester's words quoted exactly, never summarised,
  and labelled with its kind and impact. If the same problem is already filed, the report
  is added to that issue as a comment instead, and the issue is reopened if it had been
  closed. For an app tracked on the board alone, the report stays where it is and is
  worked in place.
- **Works it.** By a written policy, in order: is it complete, is it actually a bug,
  can it be reproduced, is it safe to fix unattended, and finally fix it and prove the
  fix by running the app. [What happens to a report](what-happens-to-a-report.md) has the
  whole policy in plain words.

## 5. The outcome comes back to the board

Whatever the session decides is written onto the report: a status, what it found, and a
short note for you. The [board](the-board.md) shows all of it, and links to the issue and
the fixing commit when there is one.

The board is also the session's memory. Before investigating a report, the session reads
what has already been found for that app. A repeat of something already worked is marked as
the same problem and linked, and the finding is reused rather than re-derived. That keeps
repeat reports cheap.

## Statuses

| Status | Meaning |
|---|---|
| Received | Sent, not yet picked up |
| Filed | An issue exists for it in the repository |
| Being looked at | A session is working on it now |
| Fixed | Fixed, proven by running the app, and merged |
| Needs a person | Diagnosed, but the fix is not one to make unattended |
| Couldn't reproduce | Tried three times; what was tried is on the report |
| Working as designed | The app did what it was designed to do, and the report says why |
| App isn't explaining itself | The app did what it was designed to do but the tester expected otherwise, which is its own finding |
| Triaged | Read, labelled and routed; waiting on a person or on a product decision |

## What Beacon needs to run

- The Beacon page, owned by a Claude organisation. Testers must be signed-in members of it.
- A Claude session that watches the page, a scheduled task on a Mac, or both. Reproducing
  and proving a fix for a Mac or iOS app needs a Mac; a cloud routine can pick reports up
  and file them, but the fixing half runs where the app can be built.
- For apps tracked in GitHub: the `gh` command-line tool signed in with access to the
  repository, on the machine that runs the pickup.
