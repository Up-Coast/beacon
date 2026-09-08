# Contributing

*Last updated: 2026-09-07*

Beacon is a Swift package, a page, a triage policy and the skill that runs it. Changes are
welcome to all four, and the bar is the same for each: a behaviour is not done until a test
proves it, and a rule in the policy is not done until the skill says how to apply it.

## Before you start

1. Read [internal/DEVELOPER-GUIDE.md](internal/DEVELOPER-GUIDE.md). It describes every
   module, the report's shape, the page's schema and every call the pickup makes.
2. Run the tests once so you know the starting state:

```bash
swift test
```

The same suites run on the iOS Simulator:

```bash
xcodebuild test -scheme Beacon-Package -destination 'platform=iOS Simulator,name=iPhone Air'
```

Xcode 26 with the macOS 26 and iOS 26 SDKs is required; the on-device completeness check
uses Apple's Foundation Models and the capture layer uses the current ScreenCaptureKit
and ReplayKit paths.

## Where things live

- **One home per fact.** The completeness rules are `Sources/BeaconCore/Completeness.swift`
  and the page copies them; change the Swift first, then the page, and keep the test that
  holds the two lists equal green. Label names are `IssueRenderer.Labels`; the page's
  status vocabulary and the labels script follow it.
- **The page** is `Inbox/index.html`. Never edit a published copy by hand; change the file
  and republish.
- **The policy** is `Triage/TRIAGE.md`. The skill in `.claude/skills/beacon-triage/` is how
  to run it, and the policy wins where the two seem to differ.
- **The layering** is enforced by the package graph in `Package.swift`: a target imports
  only the ones above it.

## Pull requests

- One change per pull request, with a subject line under 100 characters that says what
  changed, in words.
- Every behaviour change ships with a test. A change to what the reporter sees ships
  with a walk through the example app (`Examples/BeaconExample`) on the platform it touches.
- CI builds, tests and self-indexes on macOS. It must be green.
- Every documentation page carries a `*Last updated: YYYY-MM-DD*` line under its title.
  Move the date when you change the page.
- Write in plain words. State what a thing does, then why. No marketing.

## Reporting a problem

Open an issue. If you are reporting from inside an app that uses Beacon, use the app's
report button instead: it collects what a report needs.
