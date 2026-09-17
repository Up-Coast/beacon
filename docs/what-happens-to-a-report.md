# What happens to a report

*Last updated: 2026-09-17*

A Claude session works every report by a written triage policy, without waiting for you. It fixes and merges only what it cannot get badly wrong, and leaves everything else labelled and explained. This page is a summary. The full policy, which the session follows as written, is [TRIAGE.md](../Triage/TRIAGE.md).

## The gates

Each report goes through five gates in order. A report that fails a gate stops there and gets that gate's label.

| Gate | Passes when | Otherwise |
|---|---|---|
| 1. Is it complete? | What they expected, what happened, and the steps all say something. | `needs-info`, with at most two specific questions on the issue. |
| 2. Is it actually a bug? | What the product is supposed to do, found in the source and cited by file and line, differs from what happened. | `working-as-intended`, explained and closed. Or `expectation-mismatch`, with a separate issue about the gap in what the app tells people. |
| 3. Can it be reproduced? | A check fails because of the bug, on the build the report came from, within three attempts. | `cannot-reproduce`, with what was tried and one question. No code is changed. |
| 4. Is it simple? | Three files or fewer, 40 changed lines or fewer outside tests, no dependency change, nothing on the blast-radius list, and a cause that fits in one sentence. | `needs-human`, with a written diagnosis. |
| 5. Prove it, then merge | The whole test suite passes, and running the app through the tester's steps no longer shows the problem. | A pull request labelled `needs-human`, instead of a merge. |

A fix that passes gate 5 is merged, the commit is named on the issue, the issue is closed, and it is labelled `auto-fixed`.

The blast-radius list covers data schemas and stored user data, authentication and credentials, payments, networking, concurrency, public library APIs, build and signing configuration, and generated or vendored files. The exact list is in [TRIAGE.md](../Triage/TRIAGE.md).

## Feature requests and feedback

- **Feature requests** are never implemented unless you authorize it, however much of the feature the code already has. Triage labels one, routes it to an area, notes what already exists, and leaves it open for you.
- **Feedback** is labelled `triaged`, routed to an area, and left open.

## Severity

Triage sets severity. The app never does. The tester's `impact:` label says what the problem costs them. The `severity:` label says what it costs everyone. The scale is in [TRIAGE.md](../Triage/TRIAGE.md).

## What triage never does

- Work on a bug it could not reproduce.
- Change behaviour to match a tester's expectation without checking what the product is supposed to do.
- Implement a feature request, or act on feedback, without you authorizing it.
- Close a report as working as intended, when the tester expected something different, without first filing the expectation-mismatch issue.
- Write to a tester. Triage writes on the issue and on the board, and you decide whether anyone replies.
- Touch anything on the blast-radius list.
- Merge without running the app through the tester's own steps.

What each status means on the board is in [How it works](how-it-works.md#statuses).
