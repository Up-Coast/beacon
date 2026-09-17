# The Beacon page

*Last updated: 2026-09-17*

`Inbox/index.html` is the Beacon page: a single-file Claude artifact. Opened plainly, it is the report form testers fill in. Opened with `?view=board`, it is [the board](../docs/the-board.md). It stores reports in the artifact's own database, and a Claude session picks them up.

## Publish your own copy

Each team that adopts Beacon publishes its own copy of this file into its own Claude organization. The page belongs to whoever published it. The steps are in [Setup: the Claude-only path](../docs/setup-claude-only.md).

## Change the page

1. Edit `Inbox/index.html` in this repository.
2. Republish the file to the same page.

Never edit the live page by hand. This file is the one source, and the next republish overwrites any hand edit. Adding or changing an app needs no republish, because the page reads its app list from the database.

## Change the completeness rules

The page carries a JavaScript copy of the rules that refuse empty answers: the minimum length, the list of placeholder answers, and the messages. The Swift original is `CompletenessRules` in `Sources/BeaconCore/Completeness.swift`.

1. Change `Sources/BeaconCore/Completeness.swift` first, and run its tests in `Tests/BeaconCoreTests/CompletenessTests.swift`.
2. Copy the same change into `Inbox/index.html`, keeping the values and messages identical.
3. Republish the page.

No test compares the two copies, so check them against each other by hand. The query keys the page reads are a separate contract. `everyKeyIsOneThePageReads` in `Tests/BeaconCoreTests/InboxLinkTests.swift` compares the Swift keys with a list copied from the page, so update that list when the page's keys change.

## How the page works inside

The storage layout, the doorbell, the query keys and the page's views are in the [developer guide](../internal/DEVELOPER-GUIDE.md).
