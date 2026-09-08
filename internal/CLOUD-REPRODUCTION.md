# Reproducing and verifying without your own machine

The question this answers: *can a bug be reproduced, fixed, and the fix
proven, on a machine that isn't mine?*

**Yes for the whole loop, with one real constraint** — the verification leg
has to run on macOS, and macOS runners cost about ten times what Linux
ones do.

## What runs where

| Step | Where | Why |
|---|---|---|
| Read the queue, check completeness, check product intent | Linux | Reading code and issues. Cheap. |
| Reproduce, and prove the fix by running the app | **macOS** | A Mac app runs only on a Mac; an iOS app runs in the iOS Simulator, which also lives only on a Mac. |
| Comment, label, merge | Linux | GitHub API calls. |

`beacon-triage.yml` runs the first and last on Linux and hands the middle
to `beacon-reproduce.yml` on macOS, so the expensive runner is used only for
the part that genuinely needs it.

## The macOS runners, as GitHub documents them

- `macos-26` and `macos-26-xlarge` — macOS 26 on Apple silicon (arm64).
  `macos-latest` also points at macOS 26 today, but it moves; the shipped
  workflow pins `macos-26` so a reproduction run is repeatable later.
- `macos-26-intel` / `macos-26-large` — x86_64, if you need it.
- Xcode is preinstalled: one major version per macOS image, with its minor
  versions, and three major.minor platform tools and simulator runtimes.

## What it costs

GitHub's published rates: **macOS $0.062 a minute, Linux $0.006** — about
ten to one. Private repositories include 2,000 minutes a month on Free,
3,000 on Pro and Team.

So a ten-minute reproduction is roughly **62 cents**. That is nothing per
report and real money if it fires on every issue, which is why
`beacon-reproduce.yml` is triggered by hand or by the triage job and never
on a schedule.

Keep it down by: pinning the runner (no surprise image changes),
`fetch-depth: 0` only where history is genuinely needed, caching
`.build`, and a `timeout-minutes` on every job so a wedged run can't burn
an afternoon.

## Starting the app with data already in it

This is the part that makes an unattended reproduction possible at all.
Almost every real report starts "I opened the project called Harbour", and
a reproduction against an empty app proves nothing.

`BeaconSeed` copies a known folder over the app's data directory at launch,
gated behind **two** environment variables, because one is a typo away from
replacing somebody's real data:

```bash
BEACON_SEED_ENABLE=1
BEACON_SEED_DIRECTORY=Triage/seeds/two-projects
```

In the host app, at launch, before anything reads the data directory:

```swift
let result = BeaconSeed.applyIfRequested(into: Paths.applicationSupport)
Beacon.log.notice(result.explanation)

if BeaconSeed.isReproductionRun() {
    // Skip onboarding, sign-in walls, anything that would stop an
    // unattended run before it reached the reporter's steps.
}
```

Keep a seed folder per common shape under `Triage/seeds/`: empty, one
project, several projects, a project mid-run. Commit them — they are
fixtures, and they need to be the same next month.

Every outcome explains itself into the log, including the failures, so a
run that *didn't* start from the data it meant to says so instead of
quietly proving the wrong thing.

## Wiring the actual run

`beacon-reproduce.yml` ships with the run step deliberately failing, so a
half-wired workflow can't report a green run that proved nothing. Point it
at the app's own UI test scheme:

```yaml
- run: |
    xcodebuild test \
      -scheme HarbourUITests \
      -destination 'platform=macOS' \
      -only-testing:HarbourUITests/BeaconReproduction \
      -resultBundlePath reproduction.xcresult
```

Write the reproduction test from the issue's numbered steps, one step per
line, and screenshot at the step that's supposed to be wrong. That
screenshot is the evidence the triage policy requires before a fix may be
merged.

## What about iOS

Easier, when it comes. iOS Simulators run on the same macOS runners, a
simulator's data container can be seeded by copying a folder into it, and
`xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'`
needs no display session. The same seeding mechanism and the same policy
apply unchanged; only the run step differs.

## What is *not* possible

- Running a **Mac app** on a Linux runner. There is no path; it's a
  different operating system.
- Reproducing anything that depends on the reporter's own machine —
  their files, their network, their peripherals, their Apple Intelligence
  being switched on. Those reports need a person, and the triage policy
  sends them to `needs-human` rather than pretending.
- Reproducing a bug the reporter couldn't reproduce either. That's the
  `cannot-reproduce` path, and no amount of compute changes it.
