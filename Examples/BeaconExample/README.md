# BeaconExample

*Last updated: 2026-09-17*

A small app for trying Beacon's in-app sheet on iPhone, iPad and Mac. It has a counter, a button that writes a warning to the log, the report button, and the walkthrough on first run.

Reports go to `LocalBundleTransport`, so nothing leaves the device. Each report is saved in the app's Application Support folder, under `Beacon Example/Beacon/reports/`.

The app uses the Beacon package from this repository (`path: ../..` in `project.yml`), so it builds with your local changes.

## Run it in Xcode

1. Install XcodeGen, once:

   ```bash
   brew install xcodegen
   ```

2. Generate the project in this folder. `project.yml` defines it, and the generated `.xcodeproj` is not committed.

   ```bash
   cd Examples/BeaconExample
   xcodegen generate
   ```

3. Open the project:

   ```bash
   open BeaconExample.xcodeproj
   ```

4. Pick an iOS simulator or **My Mac** as the destination, and run the `BeaconExample` scheme.

## Build from the command line

After step 2, build for the iOS Simulator:

```bash
xcodebuild build -project BeaconExample.xcodeproj -scheme BeaconExample -destination 'platform=iOS Simulator,name=iPhone Air'
```

Build for the Mac:

```bash
xcodebuild build -project BeaconExample.xcodeproj -scheme BeaconExample -destination 'platform=macOS'
```

## What to try

- The consent screen.
- Each of the three kinds: bug, feature request and feedback.
- The steps list on a bug.
- A screenshot and a screen recording.
- **Choose from Photos**, on iOS.
- The review screen, then send, then the saved report folder.

A screen recording needs a physical iPhone or iPad. On the iOS Simulator the recording comes back empty, and the sheet shows that it could not be attached.
