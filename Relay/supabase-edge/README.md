# The Beacon relay, as a Supabase Edge Function

*Last updated: 2026-10-06*

The relay lets people report from your app without a GitHub account. The app sends each report here with `RelayTransport`. The relay checks the app's token, checks the report, and files it as an issue in your private repository with a GitHub App. The person reporting is told only that the team has it.

To deploy it, follow [Setup: the relay](https://github.com/Up-Coast/beacon/blob/main/docs/setup-relay.md). This page describes what the function does and how to change it.

## Files

| File | What it is |
|---|---|
| `supabase/functions/beacon-relay/index.ts` | The entry point. Reads the settings once, then hands every request to `relay.ts`. |
| `supabase/functions/beacon-relay/relay.ts` | Everything the relay does. |
| `supabase/functions/beacon-relay/relay_test.ts` | Tests for the token check, routing, the report checks, rate limits, signing and filing. They make no network calls. |

## Settings

Set these as Supabase secrets.

| Setting | Required | What it is |
|---|---|---|
| `BEACON_APP_TOKEN` | Yes | The value your app sends as `appToken`. Make it long and random. It is not a GitHub credential. |
| `GITHUB_APP_ID` | Yes | Your GitHub App's App ID. |
| `GITHUB_APP_PRIVATE_KEY` | Yes | The whole `.pem` file GitHub gave you, including its first and last lines. |
| `GITHUB_INSTALLATION_ID` | No | The app's installation. Left out, the relay asks GitHub which installation covers each repository, once per repository. |
| `TARGET_OWNER`, `TARGET_REPO` | One of these or `TARGETS` | The repository reports are filed in. |
| `TARGETS` | One of these or the pair above | Several apps through one relay. A JSON object from bundle identifier to `"owner/repo"`, or to `{"repo": "owner/repo", "installation": "123"}` for a repository in another installation. An app not listed goes to `TARGET_OWNER`/`TARGET_REPO`, or is refused when those are not set. |
| `RATE_LIMIT_PER_IP` | No | Reports one address may send in an hour. Default 30. |
| `RATE_LIMIT_PER_DEVICE` | No | Reports one install may send in an hour. Default 10. |

```text
TARGETS={"com.example.harbour": "your-org/harbour", "com.example.lighthouse": "your-org/lighthouse"}
```

## What it does with a request

1. Refuses anything but `POST`, and any request whose `Authorization: Bearer` value is not `BEACON_APP_TOKEN`. The comparison takes the same time however much of the token matches.
2. Refuses an address that has sent its hourly count. The address is the last `X-Forwarded-For` entry, the one the platform's proxy added; earlier entries are whatever the caller wrote.
3. Reads the body with a running count and stops at 31 MiB, whatever `Content-Length` says.
4. Checks the report's shape: a title, a body of at most 50,000 characters (GitHub takes 65,536, and the attachment links are added after), a `BN-` reference, an account, a bundle identifier or nothing, at most 20 labels and 30 attachments, attachments in base64 totalling at most 30 MiB. `RelayTransport` checks the same limit before sending. Labels other than Beacon's own (`beacon`, `type:*`, `impact:*`, `area:<id>`) are dropped, so a request cannot make the GitHub App create labels.
5. Refuses an install that has sent its hourly count. The install is the report's `account`.
6. Picks the repository from the report's `app`, its bundle identifier.
7. Signs a JWT as the GitHub App and exchanges it for an installation token. The token is reused until five minutes before it expires.
8. Files the report the way `GitHubIssueTransport` in [`Sources/BeaconGitHub/Transports.swift`](https://github.com/Up-Coast/beacon/blob/main/Sources/BeaconGitHub/Transports.swift) does: each attachment is committed to the `beacon-attachments` branch at `.beacon/attachments/<reference>/<filename>`, each filename in the body becomes a link, and then the issue is created with its labels. If GitHub refuses the attachments with a 403 or 404, the issue is filed with a note that the files stayed on the reporter's device. If a file is already there, because an earlier send of the same report committed it and then failed, the relay links the file already committed.
9. Answers `201` with `{"issue_number": …, "html_url": …}`. The app keeps both in its saved copy of the report and shows neither.

Every refusal answers with `{"error": "…"}`. The sentences are in `ANSWERS` at the top of `relay.ts`, and none of them names GitHub. `RelayTransport` shows the reporter its own sentence for the status instead, so a relay's message never reaches them.

Filenames are made safe before they become a path, the same way the app's saved copy does it. The Swift code is the reference: when the attachment layout or the link rewriting changes there, change it here too.

## Limits to know

- **Rate limits are kept in memory.** Each running copy of the function counts on its own, and the counts reset when Supabase starts a new copy. Each limiter keeps at most 10,000 addresses or installs and forgets the oldest first. They slow a runaway app or a noisy device. They do not stop someone determined.
- **The app token ships inside the app**, so treat it as a door key, not a secret. Anyone who pulls it from the app can send reports. Change it, and ship an app update, if you see reports nobody sent.
- **Supabase's limits apply.** Supabase lists 256 MB of memory and 2 seconds of CPU time per request. The relay holds about three copies of a request at once (the bytes, the text and the parsed report), which is why it accepts 31 MiB, and why `RelayTransport` refuses a report whose attachments come to more than 30 MiB of base64 even though the sheet lets them total 60 MiB. It passes attachments to GitHub in the base64 the app sent, without decoding them.

## Tests

With [Deno](https://deno.com) installed, run this in `Relay/supabase-edge`:

```bash
deno test supabase/functions/beacon-relay/
```
