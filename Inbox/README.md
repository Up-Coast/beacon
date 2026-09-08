# The inbox — reporting through a shared page

`index.html` is a Claude artifact. Testers open it from inside an app (or
from a link), file a bug, a request or feedback, and a Claude session
picks the report up and works it against `Triage/TRIAGE.md`.

Every adopter publishes their own copy from this same file into their own
Claude organisation (`docs/setup-claude-only.md`); the page belongs to
whoever published it. Republish from this file, never edit the live page by
hand — this file is the one home.

## How a report travels

1. The app builds the link with `BeaconInbox.url(...)` (`Sources/BeaconCore/
   InboxLink.swift`): app, version, build, commit, OS, device, locale,
   appearance and who is signed in ride as query parameters. The page reads
   exactly those names; `InboxLinkTests` holds the two lists equal.
2. The page enforces the same gate as the native sheet — the three required
   bug fields, the placeholder list, the twelve-character floor, the
   reproducibility nudge — copied verbatim from `Completeness.swift`.
   Change the rules there first, then here.
3. On send, the report is written to the artifact's database as
   `reports/<BN-reference>` with `status: "new"`, in the shape of
   `FeedbackReport`. Images the reporter added (file picker, camera on
   iOS, or paste on a Mac) are shrunk on their device to at most 1600 px
   and about 180 KB of JPEG, then stored one per document under
   `reports/<BN-reference>/attachments/<n>` — a database document holds at
   most 256 KiB. Up to six per report. Then the page publishes a one-line
   `data/doorbell.json` as a new version of the artifact. **That publish is
   what wakes a Claude session watching the artifact** — database writes
   alone wake nothing.
4. The tester is done. They are never written back to.
5. The pickup (a watching session, or the scheduled task
   `beacon-inbox-triage`) turns each new report into a GitHub issue on the
   app's repository in the same format the native sheet files — or, when
   the same problem is already filed, a comment on that issue — and marks
   the report `filed` with the issue number. From there every report,
   whichever way it arrived, is one queue worked by the triage policy.

## Two views of one page

- **The tester's view** is the form and nothing else. Open the artifact
  URL (with `?app=` from inside an app) and it shows the form; after
  sending, a receipt with the reference. Testers never see other reports.
- **The founder's board** is the same artifact with `?view=board`: every
  report, newest first, filtered by app, status and kind, searchable, each
  one expandable to the full record — the reporter's words verbatim, the
  machine facts, the images, the issue link, the finding and the fix. It
  is read-only; the pickup writes the status.

Each app in `apps` carries `tracker`: `"github"` (reports become issues;
the board mirrors their status) or `"board"` (no GitHub — the report is
worked in place and the board is the whole tracker). That is the
non-GitHub route, and it needs no other tool.

## Which app a report is about

The list of apps is the `apps` collection in the artifact's database — one
document per app, `{name, platform, repository, folder}` — seeded and
edited with the Artifact tool's `write_db`, never typed into the page. The
page offers them as a picker. `?app=<id or name>` preselects one, and a
link that also carries `version` (so it came from inside the app) locks
the choice. One page serves every app; a report carries
`app: {id, name, repository, platform}` so triage routes it without
guessing. Adding an app is one `write_db` call, no republish.

## What this route can and can't do

- **Testers must be signed-in members of the owner's Claude organisation.**
  An artifact that declares `db` is organisation-internal by contract and
  cannot be shared publicly. This route is for internal and highly trusted
  testers; a public beta needs the GitHub or relay transport.
- The artifact has to be shared with each tester with **edit** access, or
  the doorbell rejects `not_writer` and the report waits for the scheduled
  check. Sharing is done from the page's share menu by the owner.
- A watch lives only while an interactive Claude session holds it. The
  scheduled task is the floor; the watch is the fast path.
- Nothing the machine collects beyond the query string comes along — no
  log tail, no settings, no folder shape. Those need the native sheet and
  a transport that accepts attachments. Images do come along, shrunk;
  recordings and other files don't.
- Works the same on macOS and iOS, because it is a browser page.

## Status vocabulary

The page maps `status` to a label. Triage writes one of: `triaging`,
`auto-fixed`, `needs-info`, `cannot-reproduce`, `needs-human`,
`working-as-intended`, `expectation-mismatch`, `triaged`. These are the
label names from `IssueRenderer.Labels`, so both halves stay one vocabulary.
