# FAQ

*Last updated: 2026-09-17*

**Do my testers need an account?**

For the Beacon page, yes: a Claude account in the organization that owns the page, signed in. For the in-app sheet with the GitHub transport, a GitHub account. See [Setup: the GitHub path](setup-github.md).

**Can one page serve several apps?**

Yes. Every app is a row in the page's app list, the link from each app selects it, and the board filters by app. See [Options](options.md).

**Does the tester hear back?**

Not through the page. The tester gets a reference and is done, and the outcome is written onto the report on your [board](the-board.md). For reports filed as GitHub issues, triage replies on the issue.

**What if the same thing is reported twice?**

The pickup compares each new report with what is already filed. A repeat is added to the existing issue as a comment, and on the page it takes the earlier report's status and finding. See [How it works](how-it-works.md).

**Will it change my code without asking?**

Only for a bug that reproduces, has a cause that fits in one sentence, stays within the size limits, touches nothing on the blast-radius list, and is proven by running the app. Everything else gets a diagnosis or a pull request for a person. See [What happens to a report](what-happens-to-a-report.md).

**Will it build features?**

No. Feature requests are labelled, routed and left for a person. See [What happens to a report](what-happens-to-a-report.md).

**Can the pickup run when my Mac is off?**

With the GitHub setup, triage can run in a scheduled GitHub Actions workflow, and reproduction can run on a GitHub-hosted macOS runner. Reports on the Beacon page need a Claude session to pick them up. See [Setup: the GitHub path](setup-github.md).

**What is read from the tester's device?**

On the Beacon page, only what the app put in the link and what the tester typed or attached. The in-app sheet can add more. [What is collected](what-is-collected.md) lists all of it.

**Can I turn off images or screen recording?**

On the page, images are the tester's choice for each report. In the in-app sheet, set `allowsScreenRecording` to `false`. See [Options](options.md).

**Does the in-app sheet work on iPhone and iPad?**

Yes. The same package and the same call work on macOS and iOS. [What is collected](what-is-collected.md) describes screenshots and recordings on each platform.

**Can a tester see other testers' reports?**

Not on the form. Anyone who can open the page can open the board by adding `?view=board`. See [The board](the-board.md).

**What does the reference look like?**

`BN-` followed by six characters, such as `BN-8EA6C3`, made when the report is sent. It is on the tester's receipt, on the board, and in the page's record of the report.
