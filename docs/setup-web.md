# Setup: a website

*Last updated: 2026-10-08*

People report from your website with no GitHub account, and the reports become issues in your private repository. They never see the word GitHub. Use this path for a website or web app.

You need the [relay](setup-relay.md) set up first: steps 1 to 3 there give you the GitHub App, its installation on your repository, and the deployed relay with its app token.

## 1. Route the site to its repository

Add the site to the relay's `TARGETS` secret, with any identifier you choose for `app.id`:

```bash
supabase secrets set --project-ref <project-ref> \
    TARGETS='{"ca.example.site": "your-org/your-site"}'
```

Keep the entries for your other apps in the same JSON object. The secret is replaced as a whole.

## 2. Allow the site's origin

A browser only gets an answer from the relay for a site you list. Set `ALLOWED_ORIGINS` to every address the site is served from, comma separated, with no path:

```bash
supabase secrets set --project-ref <project-ref> \
    ALLOWED_ORIGINS='https://example.com,https://www.example.com'
```

Redeploy the relay once so it has the browser support in this release:

```bash
cd ~/beacon/Relay/supabase-edge
supabase functions deploy beacon-relay --project-ref <project-ref> --no-verify-jwt
```

Native apps are unaffected: a request with no `Origin` header is answered as before.

## 3. Create the labels

```bash
./Scripts/beacon-labels.sh your-org/your-site
```

## 4. Add Beacon to the site

```bash
pnpm add github:Up-Coast/beacon#v0.7.0&path:/Web
```

Mount it once, on the client, on every page:

```ts
import { Beacon } from "@up-coast/beacon-web";

Beacon.mount({
  app: { id: "ca.example.site", name: "Example" },
  relay: { url: "https://<project-ref>.supabase.co/functions/v1/beacon-relay", token: "<app token>" },
  organizationName: "the Example team",
});
```

The token is visible in the page's source. That is how it works in a native app too: it is a door key that lets someone send a report, never a GitHub credential, and the relay answers only the origins you listed.

## 5. Check it

Open the site, press **Report a problem**, and send a feedback report. An issue labelled `beacon` and `type:feedback` appears in the repository within a few seconds. Close it when you are done.

Triage works the same as for an app: set it up with [Setup: the GitHub path](setup-github.md) steps 1 and 3.
