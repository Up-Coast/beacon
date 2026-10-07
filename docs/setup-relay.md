# Setup: the relay

*Last updated: 2026-10-06*

People report from inside your app with no GitHub account, and the reports become issues in your private repository. They never see the word GitHub: the sheet says their report goes to the team, and thanks them with a reference they can quote. Use this path when the people reporting are your app's users, not developers.

The app sends each report to a small function you run, the relay. The relay holds the only GitHub credential, a GitHub App's private key, and the app holds only a token that lets it talk to the relay. Beacon ships a reference relay for Supabase Edge Functions in [`Relay/supabase-edge`](https://github.com/Up-Coast/beacon/tree/main/Relay/supabase-edge).

You need admin access to the repository, a Supabase project, and the [Supabase CLI](https://supabase.com/docs/guides/cli) signed in with `supabase login`.

Triage works the same as on the GitHub path. To set that up, follow [Setup: the GitHub path](setup-github.md) steps 1 and 3, and skip its steps 2, 4 and 6.

## 1. Create a GitHub App

The GitHub App is what files the issues. It can reach only the repositories you install it on, and only with the two permissions below.

1. On GitHub, click your profile picture, then **Settings**. For an organization's repository, open that organization's settings instead.
2. Click **Developer settings**, then **GitHub Apps**, then **New GitHub App**.
3. Fill in **GitHub App name** and **Homepage URL**.
4. Under **Webhook**, untick **Active**. The relay receives no events.
5. Under **Permissions**, **Repository permissions**, set:
    - **Contents**: Read and write. Attachments are committed to the `beacon-attachments` branch.
    - **Issues**: Read and write.
6. Under **Where can this GitHub App be installed?**, choose **Only on this account**.
7. Click **Create GitHub App**.
8. Copy the **App ID** from the page that opens.
9. Under **Private keys**, click **Generate a private key**. A `.pem` file downloads. Keep it out of every repository; it goes into Supabase in "Deploy the relay" and nowhere else.

## 2. Install it on the repository

1. On the app's page, click **Install App**, then **Install** beside the account that owns the repository.
2. Choose **Only select repositories** and pick the repository reports go to.
3. Click **Install**.

To route several apps through one relay, select each of their repositories here.

## 3. Deploy the relay

1. Clone Beacon if you have not, and go to the relay's folder:

    ```bash
    git clone https://github.com/Up-Coast/beacon.git ~/beacon
    cd ~/beacon/Relay/supabase-edge
    ```

2. Run `supabase init` once in this folder. It writes `supabase/config.toml`, which holds your project's own settings, so Beacon does not ship one. Answer no to any question it asks.

3. Make a long random app token. You give the same value to the relay and to your app:

    ```bash
    openssl rand -hex 32
    ```

4. Set the secrets, with your project's reference from the Supabase dashboard:

    ```bash
    supabase secrets set --project-ref <project-ref> \
        BEACON_APP_TOKEN=<the app token> \
        GITHUB_APP_ID=<the App ID> \
        TARGET_OWNER=<your-org> \
        TARGET_REPO=<the repository> \
        GITHUB_APP_PRIVATE_KEY="$(cat ~/Downloads/<your-app>.private-key.pem)"
    ```

    To send several apps to different repositories, set `TARGETS` as well. The relay's [settings](https://github.com/Up-Coast/beacon/blob/main/Relay/supabase-edge/README.md#settings) list every value.

5. Deploy:

    ```bash
    supabase functions deploy beacon-relay --project-ref <project-ref> --no-verify-jwt
    ```

    `--no-verify-jwt` is required. Your app sends its own token, not a Supabase sign-in, and the relay checks that token itself.

6. Delete the `.pem` file from your Downloads folder.

The relay's address is `https://<project-ref>.supabase.co/functions/v1/beacon-relay`.

## 4. Configure the app

1. Follow [Quickstart](quickstart.md) steps 1 and 2.
2. Replace the `Beacon.configure` call with this one:

    ```swift
    import Beacon

    @MainActor
    func configureBeacon() {
        Beacon.configure(
            BeaconConfiguration(
                app: AppIdentity.mainBundle(commit: BuildInfo.commit),
                organizationName: "the Harbour team",
                currentReporter: { .anonymous() },
                transport: FallbackTransport(
                    primary: RelayTransport(
                        endpoint: URL(string: "https://<project-ref>.supabase.co/functions/v1/beacon-relay")!,
                        appToken: "<the app token>",
                        destinationName: "the Harbour team"),
                    fallback: LocalBundleTransport(folderProvider: {
                        ReportArchive(directory: BeaconConfiguration
                            .defaultArchiveDirectory(appName: "Harbour")).saved().first
                    }))),
            audience: .everyone)
    }
    ```

    `.anonymous()` lets anyone report, with a random id made for this install and nothing else about them. The sheet then asks "How can we reach you? (optional)". If your app has its own accounts, return a `Reporter` for whoever is signed in instead.

    The app token is in your app's binary, so anyone determined can read it. It lets them send reports and nothing else. The relay limits how many reports one address and one install can send in an hour.

3. Put the sheet in and generate the app map: [Setup: the GitHub path](setup-github.md) step 4, items 3 to 6.
4. Build the app and send a test report. The sheet says it was sent to the team. The issue appears in the repository, labelled `beacon`. Close it when you are done.

For a sandboxed Mac app, add the **Outgoing Connections (Client)** entitlement. See [Platform permissions](options.md#platform-permissions).

## 5. Tell the people reporting

Send them [For testers](for-testers.md), or copy it into your own help. Nothing else is needed: no account, no sign-in. Its last section is for apps that ask for a GitHub sign-in, so leave it out of a copy.
