# BeaconExample

The smallest app Beacon can be walked in: a counter to report about, a
button that writes a warning to the log, the report button, and the
walkthrough on first run. Reports go to `LocalBundleTransport`, so nothing
leaves the device; the saved folder is under the app's Application Support
directory, in `Beacon Example/Beacon/reports/`.

It exists to be run, not shipped. `project.yml` is the source of truth; the
Xcode project is generated from it and not committed.

## Generate and open

```bash
brew install xcodegen      # once
xcodegen generate          # in this folder
open BeaconExample.xcodeproj
```

One target, `BeaconExample`, with iOS and macOS destinations. Pick a
simulator or My Mac and run.

## From the command line

```bash
xcodebuild build -project BeaconExample.xcodeproj -scheme BeaconExample \
    -destination 'platform=iOS Simulator,name=iPhone Air'
xcodebuild build -project BeaconExample.xcodeproj -scheme BeaconExample \
    -destination 'platform=macOS'
```

## What to walk

Consent, each of the three kinds, the steps list, a screenshot, a
recording, a photo from the library (iOS), review with the full preview,
send, and the saved report. On the iOS Simulator a recording starts and
stops but the simulator's recorder writes an empty file; the sheet says so.
A physical iPhone or iPad is needed to see a recording and its frames land
on a report.

The depended-on package is this repository (`path: ../..`), so a change to
Beacon is in the example on the next build.
