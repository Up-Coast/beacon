# The Beacon relay, on Firebase

*Last updated: 2026-11-10*

A second host for the relay and the private store, beside [the Supabase one](../supabase-edge/README.md). It runs the same code: `src/` only turns a Firebase request into a web `Request`, calls the handler in `../supabase-edge/supabase/functions/`, and writes the `Response` back. Change what the relay does in `relay.ts` and `private.ts`, never here.

To deploy it, follow [Host the relay on Firebase](../../docs/setup-relay.md#host-the-relay-on-firebase).

## Files

| File | What it is |
|---|---|
| `src/index.ts` | Exports the two functions, `beaconRelay` and `beaconPrivate`, with their memory, timeout, concurrency and instance limits. |
| `src/host.ts` | Builds each handler from the settings secret. |
| `src/web.ts` | Node request to web `Request`, web `Response` to Node response, and the caller's address. |
| `src/store.ts` | The private store on a Cloud Storage bucket. |
| `storage.rules` | Denies every read and write from an app. |
| `test/` | Tests for the host, run with vitest. |

## Settings

One secret, `RELAY_SECRETS`, holds a JSON object with the relay's setting names ([Supabase README](../supabase-edge/README.md#settings)) and the private store's. `TARGETS` is a nested object. The private key keeps its line breaks as `\n`, which the relay converts. `PRIVATE_BUCKET` names a bucket other than the project's default. The Supabase-only settings are not used.

## Limits

Each function is public, has 1 GiB of memory, a 120 second timeout and 4 concurrent requests per instance, and runs at most 3 instances (the relay) or 2 (the private store).

The relay accepts requests up to `MAX_REQUEST_BYTES` in `relay.ts`, 32,505,856 bytes. Google documents the limit for a 2nd-generation function as 32MB and Cloud Run's as 32 MiB (33,554,432 bytes). The first reading is below the relay's cap. The tests prove the relay's own cap with an attachment of 30 MiB encoded, and cannot prove the platform's. Before any client uses this host, send a request of exactly `MAX_REQUEST_BYTES` to the deployed function. If it refuses, lower the cap here and `defaultMaximumEncodedBytes` in `Sources/BeaconGitHub/Transports.swift` to what it accepts.

Rate limits are kept in memory and counted per caller address. `clientAddressOf` in `src/web.ts` reports the last `X-Forwarded-For` entry, the one the platform's proxy adds, and the connection's own address when there is none. On the deployed function, send from two networks and confirm they are counted separately. If every caller appears as one address, the limit applies to all users together and `clientAddressOf` must change.

## The private bucket

Sealed messages are objects named `beacon-private/<bundle id>/<uuid>.bin` in the project's default bucket. `storage.rules` denies every app, so only the function and the owner's tool, both with service credentials, reach it. A write uses `ifGenerationMatch: 0`, so it succeeds only when no object has that name, and a second upload of the same id answers `409`.

Read what is stored with `beacon-private read <name> --store gcs --bucket <bucket>` ([Setup: private delivery](../../docs/setup-private.md#5-read-what-was-sent)).

## Tests

Run them in this folder, with Node 22 and Java 21 for the emulator, using a `demo-` project id so nothing real is touched:

```bash
npm install
npm run typecheck
npm run test:emulator
```

The Storage emulator accepts a second write to an existing name, so it cannot show `ifGenerationMatch: 0` refusing one. A test against a stand-in for Storage proves the client sends the option and that a `412` answers `409`.
