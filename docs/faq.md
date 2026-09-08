# FAQ

*Last updated: 2026-09-07*

**Do my testers need an account?**
For the Beacon page, a Claude account in your organisation. They sign in once. For the
GitHub path's in-app sheet, a GitHub account with access to the repository.

**Can I use one page for several apps?**
Yes. Every app you own shares one page; the app tells the page which one it is, and the
board filters by app.

**Does the tester hear back?**
No. They send and carry on. The outcome is written to your board and, for apps tracked
in GitHub, onto the issue. If you want to tell a tester what happened, the board has the
words ready.

**What if the same thing is reported twice?**
The second report is attached to the first as a comment on its issue, and on the board it
is marked as the same problem, with the earlier finding reused. The work is done once.

**Will it change my code without asking?**
Within the [policy](what-happens-to-a-report.md), yes: a bug that reproduces, whose cause
can be stated in one sentence, and that touches nothing on the blast-radius list is fixed,
proven by running the app, and merged. Everything else becomes a diagnosis for you, or a
pull request when the proof could not be produced.

**Will it build features?**
Not unless the code already has most of the feature, and then the note says so. Feature
requests are routed and left for you.

**What does it cost?**
Reading a report and filing it is cheap. Reproducing and fixing a bug is a coding session,
and that is where the cost is. Repeat reports reuse earlier findings rather than paying
again, and a report that does not reproduce stops after three attempts.

**Can the pickup run when my Mac is off?**
Picking up and filing reports can run in the cloud. Reproducing and proving a fix for a Mac
or iOS app needs a Mac: yours, on a schedule, or a hosted macOS runner.

**Is anything read from the tester's machine?**
On the Beacon page, nothing beyond what the app put in the link and what the tester typed
or attached. [What is collected](what-is-collected.md) lists it.

**Can I turn off images, or recording?**
Images on the page are the tester's choice, report by report. Recording is a configuration
switch on the in-app sheet (`allowsScreenRecording`), for the GitHub route, on macOS and
iOS alike.

**Does the in-app sheet work on iPhone and iPad?**
Yes, the same package and the same call. On iOS a screenshot is drawn from the app's own
screen, a recording goes through iOS's own screen recorder after it asks the tester, the
sheet shrinks to a strip while recording so the app stays usable, and testers can also pick
a screenshot or recording they already took from Photos. [The GitHub route](github-route.md)
lists what the sheet adds.

**Can a tester see other testers' reports?**
Not on the form. The board is a different view of the same page, and anyone in your
organisation who has the link can open it; testers are not told about it.

**Where is the reference number from?**
`BN-` plus six characters, made when the report is sent. It is on the tester's receipt, on
the board, and in the issue, so any of the three can be found from the others.
