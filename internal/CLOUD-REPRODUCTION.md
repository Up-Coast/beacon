# Reproducing on GitHub-hosted runners

*Last updated: 2026-09-17*

A bug can be reproduced, fixed and the fix proven on GitHub's runners instead of your own Mac. One leg has to run on macOS, and macOS runners cost about ten times what Linux runners do.

## What runs where

| Step | Runner | Why |
|---|---|---|
| Read the queue, check completeness, check the report against what the product should do | Linux | Reading code and issues |
| Reproduce, and prove the fix by running the app | macOS | A Mac app runs only on a Mac, and the iOS Simulator only runs on a Mac |
| Comment, label, merge | Linux | GitHub API calls |

`beacon-triage.yml` runs on `ubuntu-latest` on a weekday cron. `beacon-reproduce.yml` runs on `macos-26` and is started by hand with `workflow_dispatch`, never on a schedule, so the expensive runner is used only when a report needs it.

## The runners

From [GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [larger runners](https://docs.github.com/en/actions/reference/runners/larger-runners):

| Label | Architecture | CPU | RAM |
|---|---|---|---|
| `macos-26` | arm64 (M1) | 3 | 7 GB |
| `macos-26-intel` | Intel | 4 | 14 GB |
| `macos-26-large` (larger runner) | Intel | 12 | 30 GB |
| `macos-26-xlarge` (larger runner) | arm64 (M2) | 5 | 14 GB |

`macos-latest` points at macOS 26 on arm64 today and moves when GitHub moves it. The shipped workflow pins `macos-26` so a reproduction run is repeatable later.

## What it costs

GitHub's [published per-minute prices](https://docs.github.com/en/billing/reference/actions-runner-pricing): Linux 2-core is $0.006, macOS 3-core or 4-core is $0.062, the macOS 12-core larger runner is $0.077, and the macOS 5-core (M2 Pro) larger runner is $0.102. A ten-minute reproduction on `macos-26` is about 62 cents.

[Private repositories include](https://docs.github.com/en/billing/concepts/product-billing/github-actions) 2,000 minutes a month on Free, 3,000 on Pro and Team, and 50,000 on GitHub Enterprise Cloud. Standard runners are free on public repositories. Larger runners are always charged, even when quota is available.

Two [limits](https://docs.github.com/en/actions/reference/limits) to plan around: a job runs for at most 6 hours, and Free, Pro and Team accounts run at most 5 concurrent macOS jobs.

Keep the bill down by pinning the runner, setting `timeout-minutes` on every job, caching `.build`, and using `fetch-depth: 0` only where the history is needed. `beacon-reproduce.yml` has a 30-minute timeout and `beacon-triage.yml` has 45.

## Starting the app with data in it

A reproduction against an empty app proves nothing, because most reports start with something the reporter had open. `BeaconSeed` copies a known folder over the app's data directory at launch, behind two environment variables, because one variable is a typo away from replacing someone's real data:

```bash
BEACON_SEED_ENABLE=1
BEACON_SEED_DIRECTORY=Triage/seeds/two-projects
```

In the host app, at launch, before anything reads the data directory:

```swift
let result = BeaconSeed.applyIfRequested(into: Paths.applicationSupport)
Beacon.log.notice(result.explanation)

if BeaconSeed.isReproductionRun() {
    // Skip onboarding, sign-in walls, and anything else that would stop an
    // unattended run before it reached the reporter's steps.
}
```

Keep one seed folder per common shape under `Triage/seeds/`: empty, one project, several projects, a project mid-run. Commit them. They are fixtures and they have to be the same next month. Every outcome is explained into the log, so a run that did not start from the data it meant to says so.

## Wiring the run step

`beacon-reproduce.yml` takes three inputs: `issue` (required), `commit` and `seed` (default `default`). It checks out the commit, runs `swift build`, sets both seed variables to `Triage/seeds/<seed>`, then fails at the run step on purpose until you point it at the app's UI test scheme:

```yaml
- run: |
    xcodebuild test \
      -scheme HarbourUITests \
      -destination 'platform=macOS' \
      -only-testing:HarbourUITests/BeaconReproduction \
      -resultBundlePath reproduction.xcresult
```

Write the reproduction test from the issue's numbered steps, one step per line, and take a screenshot at the step that is supposed to be wrong. That screenshot is the evidence the triage policy requires before a fix may be merged. The workflow uploads `.xcresult` bundles and screenshots from the run.

For an iOS app the only change is the run step: simulators run on the same macOS runners, a simulator's data container is seeded by copying a folder into it, and `xcodebuild test -destination 'platform=iOS Simulator,name=<device>'` needs no display session.

## What is not possible

- Running a Mac app or an iOS Simulator on a Linux runner. There is no path.
- Reproducing anything that depends on the reporter's own machine: their files, their network, their peripherals, their on-device model. Those reports go to `needs-human`.
- Reproducing a bug the reporter could not reproduce either. That is the `cannot-reproduce` path, and more compute does not change it.
