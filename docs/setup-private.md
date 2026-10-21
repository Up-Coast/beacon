# Setup: private delivery

*Last updated: 2026-10-21*

Private delivery lets your app send details about a problem on its own, without anyone pressing a button, to a store only you can read. Use it for details that must never become a GitHub issue, such as a customer's project names, file paths or error text about their data.

It is off unless you turn it on. Turn it on only when the people using the app have agreed to it, either through Beacon's own notice or through an agreement you hold, such as a beta tester agreement.

## How it keeps the details private

| Step | Where | What happens |
|---|---|---|
| Sweep | On the device | Every field goes through the same secret sweep as a report: keys, tokens and the app's `hostSecrets` are masked. Each field is cut to `maximumFieldLength`. |
| Seal | On the device | The details are encrypted to your public key (HPKE: Curve25519, SHA-256, ChaCha20-Poly1305). Only your private key opens them. |
| Store | The `beacon-private` function and a private bucket | Only ciphertext arrives. The function never replaces a stored message and offers no way to read one back. The bucket has no access policies, so only the function can write to it. |
| Read | Your Mac | `beacon-private read` downloads each message, opens it with the private key in your keychain, saves it outside every repository and deletes it from the bucket. |

Nothing readable reaches the relay, the bucket, Supabase or GitHub. The token the app ships can store messages but cannot read any.

## 1. Set up the store

You need the relay's Supabase project (see [Setup: the relay](setup-relay.md)) and the Supabase CLI signed in. From a clone of Beacon, run:

```bash
Relay/supabase-edge/setup-private.sh <project-ref> <name> <bundle-id>
```

`<name>` labels your keypair and token, such as your app's name. List one or more bundle identifiers to let only those apps store messages.

The script:

1. Makes your keypair. The private key goes into this Mac's keychain and is never printed. It refuses if a key for `<name>` already exists, because a new key would make every stored message unreadable.
2. Creates the private bucket `beacon-private`: 64 KiB per message, `application/octet-stream` only, no access policies.
3. Makes a random token, keeps it in this Mac's keychain (account `<name>`, service `beacon-private-app-token`), and gives it to the function.
4. Deploys the `beacon-private` function.
5. Prints the endpoint and your public key.

Keep the Mac that holds the private key backed up. Without the key, stored messages cannot be read.

## 2. Turn it on in the app

Add `privateDelivery` to your configuration. Build the token into the app the same way as the relay token, from the keychain at build time, never from source control.

```swift
Beacon.configure(BeaconConfiguration(
    app: AppIdentity.mainBundle(),
    organizationName: "the Harbour team",
    currentReporter: { .anonymous() },
    transport: RelayTransport(endpoint: relayURL, appToken: relayToken),
    privateDelivery: try PrivateDelivery(
        endpoint: URL(string: "https://<project-ref>.supabase.co/functions/v1/beacon-private")!,
        appToken: privateToken,
        ownerPublicKey: "<the public key the script printed>",
        consent: .beaconNotice)))
```

`PrivateDelivery` throws at launch if the public key is not valid. The fields are in [Options](options.md#privatedelivery).

## 3. Choose what covers sending

| `consent` | When to use it | What happens |
|---|---|---|
| `.beaconNotice` | The people using the app have not agreed to anything else | Beacon's notice gains one sentence saying the app may send details on its own, readable only by `organizationName`. The notice gets a new version, so everyone is asked again. Nothing is sent until the person has accepted it. |
| `.hostAgreement("<name of the agreement>")` | Everyone using this build agreed elsewhere, such as in a beta tester agreement | Sending does not wait for Beacon's notice. The agreement's name is sealed into every message. The notice still includes the sentence. |

## 4. Send details

```swift
let id = try await Beacon.sendPrivately(
    ["project": projectName, "cause": errorText],
    id: recordID)
```

- It returns the message's id. A public report may cite the id, so the two can be matched without the details being in the report.
- Pass your own `id` (a UUID) to make a retry land on the same message. A message that is already stored counts as sent.
- It throws `PrivateDelivery.Failure.notEnabled` when private delivery is off, and `.notConsented` until the person has accepted the notice. Nothing leaves the device in either case. Keep the details and try again later.

## 5. Read what was sent

```bash
swift run beacon-private read <name> --project-ref <project-ref>
```

Each message is saved as `~/Library/Application Support/Beacon/private/<name>/<bundle-id>/<id>.json` and deleted from the bucket. Add `--keep` to leave it in the bucket. A message that cannot be opened with this key is left in the bucket and counted.

What you read there is your customers' data. Keep it out of issues, pull requests and commits.
