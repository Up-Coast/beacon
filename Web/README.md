# Beacon for websites

*Last updated: 2026-10-08*

Beacon for websites puts a **Report a problem** button on your site. A visitor files a bug, a feature request, a change request or a thought without a GitHub account. The report arrives as a labelled issue in the same layout as a report from a Mac or iPhone app, so the same triage works it.

It is a small script with no dependencies. It sends through the [Beacon relay](../docs/setup-relay.md), which holds the only GitHub credential.

## Install

```bash
pnpm add github:Up-Coast/beacon#v0.7.0&path:/Web
```

Or load the single file `dist/beacon.global.js` with a `<script>` tag. The full steps are in [Setup: a website](../docs/setup-web.md).

## Use

```ts
import { Beacon } from "@up-coast/beacon-web";

Beacon.mount({
  app: { id: "ca.example.site", name: "Example", version: "1.4.0" },
  relay: { url: "https://<project>.supabase.co/functions/v1/beacon-relay", token: "<app token>" },
  organizationName: "the Example team",
});
```

`Beacon.mount` adds the button and the sheet. `Beacon.open()` opens the sheet from your own control (pass `button: false` to hide the floating button). `Beacon.unmount()` takes it off the page.

| Option | What it does |
|---|---|
| `app` | `id` routes the report to a repository in the relay's `TARGETS`; `name`, `version`, `build` and `commit` go on the issue. |
| `relay` | The relay address and the app token. The token is a door key, not a GitHub credential. |
| `organizationName` | Who the reporter is told the report goes to. |
| `reporter` | A signed-in person (`accountID`, `displayName`, `contact`). Without it each browser gets a random anonymous id. |
| `hostNotes` | A function returning extra `{ name, value }` facts for every report. |
| `icon` | An SVG string that replaces the mark on the button. |
| `position` | `"bottom-right"` (default) or `"bottom-left"`. |
| `button` | `false` to hide the floating button. |
| `onSent` | Called with the reference after a report is sent. |

## What a report holds

What the reporter wrote, how much it affects them, and the page address without anything after a `?` or `#`, the browser, the window size, the language and time zone, plus anything the host adds. Nothing from inside the page is read, and there are no screenshots. Anything credential-shaped in what they typed is masked first.

## Develop

```bash
cd Web
pnpm install
npx vitest run
npx tsc --noEmit -p tsconfig.json
```

Build `dist/` before you commit, because installs read it from the repository:

```bash
npx esbuild src/index.ts --bundle --format=esm --minify --outfile=dist/beacon.js
npx esbuild src/index.ts --bundle --format=iife --global-name=BeaconBundle --footer:js="window.Beacon=BeaconBundle.Beacon;" --minify --outfile=dist/beacon.global.js
npx tsc -p tsconfig.json
```

The wording, the completeness rules, the secret sweep and the issue layout are ports of `Sources/BeaconCore`. Change both together.
