# What Beacon collects, and what it doesn't

Written to be checkable. Every claim here points at the code that makes it
true, so it can be audited rather than believed.

## Collected automatically

| What | Where from | Code |
|---|---|---|
| App name, version, build, commit | The host app supplies it | `BeaconConfiguration.app` |
| System version, device model, architecture | `ProcessInfo`, `sysctl hw.model` (Mac) / `hw.machine` (iOS) | `EnvironmentProbe` |
| Language, time zone | `Locale`, `TimeZone` | `EnvironmentProbe` |
| Appearance, text size, reduced motion | `NSApp.effectiveAppearance`, `NSWorkspace` (Mac); `UITraitCollection`, `UIApplication`, `UIAccessibility` (iOS) | `EnvironmentProbe` |
| Memory, free disk | `ProcessInfo`, volume capacity | `EnvironmentProbe` |
| Whether the on-device model can run | `SystemLanguageModel.default.availability` | `EnvironmentProbe` |
| The host app's settings | The host describes them | `BeaconConfiguration.settings` |
| Names and layout of named folders | Directory listing | `FileTreeScanner` |
| The last N lines of Beacon's own log | In-memory ring | `BeaconLog` |

## Never collected

**File contents.** `FileTreeScanner` calls `contentsOfDirectory` and
`resourceValues` and never opens a file handle. It cannot read a file's
contents because it never asks for them. There is a test that writes a file
with known contents into a scanned tree and asserts those bytes appear
nowhere in the result.

**Anything outside the folders the host named.** `fileTreeRoots` is an
explicit list. Nothing is discovered.

**Anything behind the app on screen.** On the Mac, capture uses
`SCShareableContent.currentProcess`, which returns only the host process's
own windows. On iOS a screenshot is drawn from the app's own view hierarchy
(`UIGraphicsImageRenderer` over the root view — it never reads the display)
and a recording goes through `RPScreenRecorder`, which records the app's
own screen only, only in the foreground, and asks the person first. A
recording physically cannot include another app on either platform.

**Audio.** `capturesAudio = false` on the Mac's stream configuration;
`isMicrophoneEnabled = false` and `isCameraEnabled = false` on iOS.

**Credentials.** The sweep runs last, over the finished issue text and
every text attachment, against a list of credential shapes plus whatever
the host declares through `hostSecrets`. What it finds is masked and the
reporter is shown what was removed and from where — scrubbing silently
would hide a real leak in the host app's own logging.

**Your home directory name.** Every path recorded is passed through
`Redactor.redactHome`, so `/Users/sam/Projects` is recorded as
`~/Projects`.

## Where it goes

To whichever transport the host configured, and nowhere else. Beacon makes
no network call of its own except the one the transport makes. The review
screen names the destination in words before the reporter sends.

Every report is also written to a folder on the reporter's own machine
before it's sent, so a failed send never loses their work.

## The on-device check

The completeness check runs on `SystemLanguageModel.default` — Apple's
on-device model — or it does not run.

It never uses Private Cloud Compute and never any server model. Beacon does
not request the PCC entitlement and does not reference
`PrivateCloudComputeLanguageModel`. A bug report is somebody's unredacted
description of their own work; it is read where it was written, or not at
all.

Where there's no on-device model, the report is marked `review_source:
unavailable` rather than passing silently — so a report nothing checked can
be told apart from one that was checked and came back clean.

## Consent

Shown before the first report, versioned, and re-shown whenever the wording
changes. The version accepted is written onto every report, so there's
never a question about what somebody was told.

The notice says, in these words: reports are not anonymous; we may come
back to you; your report is copied to GitHub where other people will see
it; here's what we collect and you can read all of it before sending; we
list your file names and structure but never open them; anything you attach
yourself we do read.

## Retention

Beacon holds nothing. The reporter's copy lives in the archive folder on
their machine until they delete it. The team's copy is a GitHub issue,
governed by whatever that repository's policy is.
