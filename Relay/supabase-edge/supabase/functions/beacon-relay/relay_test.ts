// The relay's checks, with no network: run `deno test` in Relay/supabase-edge.

import {
  ANSWERS, appJWT, type Config, dependencies, handle, loadConfig, MAX_ATTACHMENT_BASE64,
  RateLimiter, routeFor, safeFilename, tokenMatches, validatePayload,
} from "./relay.ts";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}
const equal = (actual: unknown, expected: unknown) =>
  assert(JSON.stringify(actual) === JSON.stringify(expected), `${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);

const env = (values: Record<string, string>) => (name: string) => values[name];
const base = {
  BEACON_APP_TOKEN: "secret-app-token",
  GITHUB_APP_ID: "12345",
  GITHUB_APP_PRIVATE_KEY: "unused",
  GITHUB_INSTALLATION_ID: "777",
};

const report = (overrides: Record<string, unknown> = {}) => ({
  title: "Save went white",
  body: "## What they attached\n\n- `shot.png` (3 B)\n",
  labels: ["beacon", "type:bug"],
  reference: "BN-ABC123",
  account: "anonymous-1234",
  anonymous: true,
  app: "com.example.harbour",
  contact: "sam@example.com",
  attachments: [{ filename: "shot.png", base64: "AQID" }],
  ...overrides,
});

// MARK: The app token

Deno.test("the app token must match exactly", () => {
  assert(tokenMatches("Bearer secret-app-token", "secret-app-token"));
  assert(!tokenMatches("Bearer secret-app-tokem", "secret-app-token"));
  assert(!tokenMatches("Bearer secret-app-token-and-more", "secret-app-token"));
  assert(!tokenMatches("secret-app-token", "secret-app-token"), "needs the Bearer prefix");
  assert(!tokenMatches(null, "secret-app-token"));
  assert(!tokenMatches("Bearer ", ""), "an empty secret lets nobody in");
});

// MARK: Routing

Deno.test("each app goes to its own repository, and others to the default", () => {
  const config = loadConfig(env({
    ...base,
    TARGET_OWNER: "team", TARGET_REPO: "feedback",
    TARGETS: JSON.stringify({
      "com.example.harbour": "team/harbour",
      "com.example.lighthouse": { repo: "other-org/lighthouse", installation: "888" },
    }),
  }));
  equal(routeFor("com.example.harbour", config), { owner: "team", repo: "harbour", installationId: "777" });
  equal(routeFor("com.example.lighthouse", config), { owner: "other-org", repo: "lighthouse", installationId: "888" });
  equal(routeFor("com.example.unknown", config), { owner: "team", repo: "feedback", installationId: "777" });
});

Deno.test("an unknown app with no default goes nowhere", () => {
  const config = loadConfig(env({ ...base, TARGETS: JSON.stringify({ "com.example.harbour": "team/harbour" }) }));
  equal(routeFor("com.example.unknown", config), null);
});

Deno.test("missing settings are named", () => {
  let message = "";
  try {
    loadConfig(env({ BEACON_APP_TOKEN: "x" }));
  } catch (error) {
    message = (error as Error).message;
  }
  assert(message.includes("GITHUB_APP_ID") && message.includes("GITHUB_APP_PRIVATE_KEY"), message);
});

// MARK: The report

Deno.test("a report the app sends is accepted as it is", () => {
  const checked = validatePayload(report());
  assert("payload" in checked);
  equal(checked.payload.app, "com.example.harbour");
  equal(checked.payload.contact, "sam@example.com");
});

Deno.test("a report of the wrong shape is refused", () => {
  for (const bad of [null, [], "text", report({ reference: "../../x" }), report({ title: "" }),
    report({ labels: "beacon" }), report({ attachments: [{ filename: "a.png", base64: "not base64!" }] }),
    report({ contact: 42 })]) {
    const checked = validatePayload(bad);
    assert("error" in checked && checked.status === 400, `accepted ${JSON.stringify(bad)}`);
  }
});

Deno.test("attachments over the app's own limit are refused as too large", () => {
  const big = "A".repeat(MAX_ATTACHMENT_BASE64 + 4);
  const checked = validatePayload(report({ attachments: [{ filename: "big.mov", base64: big }] }));
  assert("error" in checked && checked.status === 413);
});

Deno.test("a filename can't climb out of the attachments folder", () => {
  equal(safeFilename("../../etc/passwd"), "__.._etc_passwd");
  equal(safeFilename("Screen Shot at 1.23 PM.png"), "Screen Shot at 1.23_PM.png");
  equal(safeFilename(""), "attachment");
});

Deno.test("nothing the reporter can be shown names GitHub", () => {
  for (const sentence of Object.values(ANSWERS)) {
    for (const word of ["github", "issue", "repositor", "label"]) {
      assert(!sentence.toLowerCase().includes(word), `${word} in: ${sentence}`);
    }
  }
});

// MARK: Rate limits

Deno.test("a key is held to its hourly count, and freed an hour later", () => {
  let now = 0;
  const limiter = new RateLimiter(2, () => now);
  assert(limiter.allow("a") && limiter.allow("a"));
  assert(!limiter.allow("a"));
  assert(limiter.allow("b"), "another key is counted on its own");
  now = 3_600_001;
  assert(limiter.allow("a"));
});

// MARK: The request, end to end, against a pretend GitHub

const algorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };
const pem = (label: string, der: Uint8Array) =>
  `-----BEGIN ${label}-----\n${btoa(String.fromCharCode(...der))}\n-----END ${label}-----`;

async function testKeyPair() {
  return await crypto.subtle.generateKey(
    { ...algorithm, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) }, true, ["sign", "verify"]);
}

async function testKeyPEM(): Promise<string> {
  const pair = await testKeyPair();
  return pem("PRIVATE KEY", new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey)));
}

/** The PKCS#1 key inside a PKCS#8 one: the OCTET STRING after the version and algorithm. */
function pkcs1Inside(pkcs8: Uint8Array): Uint8Array {
  let i = 1 + (pkcs8[1] & 0x80 ? 1 + (pkcs8[1] & 0x7f) : 1); // outer SEQUENCE header
  i += 3 + 15 + 1; // version, algorithm, OCTET STRING tag
  const lengthBytes = pkcs8[i] & 0x80 ? pkcs8[i] & 0x7f : 0;
  let length = lengthBytes ? 0 : pkcs8[i];
  for (let k = 1; k <= lengthBytes; k++) length = (length << 8) | pkcs8[i + k];
  i += 1 + lengthBytes;
  return pkcs8.slice(i, i + length);
}

Deno.test("the app's JWT carries the app id and a short life", async () => {
  const jwt = await appJWT("12345", await testKeyPEM(), 1_000_000);
  const claims = JSON.parse(atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
  equal(claims, { iat: 999_940, exp: 1_000_540, iss: "12345" });
});

Deno.test("a key in the form GitHub hands out signs a JWT that verifies", async () => {
  const pair = await testKeyPair();
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const jwt = await appJWT("12345", pem("RSA PRIVATE KEY", pkcs1Inside(pkcs8)), 1_000_000);
  const [header, claims, signature] = jwt.split(".");
  const bytes = Uint8Array.from(atob(signature.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
  assert(await crypto.subtle.verify(algorithm, pair.publicKey, bytes, new TextEncoder().encode(`${header}.${claims}`)));
});

function pretendGitHub(calls: string[]): typeof fetch {
  return (async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input).replace("https://api.github.com/", "");
    calls.push(`${init?.method ?? "GET"} ${url}`);
    const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status });
    if (url === "repos/team/found/installation") return json(200, { id: 999 });
    if (url.endsWith("/access_tokens")) return json(201, { token: "installation-token", expires_at: "2999-01-01T00:00:00Z" });
    if (url.includes("/git/ref/heads/beacon-attachments")) return json(200, { object: { sha: "abc" } });
    if (url.includes("/contents/")) return json(201, { content: { html_url: "https://example.com/shot.png" } });
    if (url.endsWith("/issues")) {
      const sent = JSON.parse(String(init?.body));
      assert(sent.body.includes("[`shot.png`](https://example.com/shot.png)"), "the filename became a link");
      return json(201, { number: 42, html_url: "https://example.com/issues/42" });
    }
    return json(404, { message: "Not Found" });
  }) as typeof fetch;
}

async function testConfig(): Promise<Config> {
  return loadConfig(env({ ...base, GITHUB_APP_PRIVATE_KEY: await testKeyPEM(), TARGET_OWNER: "team", TARGET_REPO: "feedback" }));
}

const post = (body: unknown, token = "secret-app-token") =>
  new Request("https://relay.example/beacon-relay", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "X-Forwarded-For": "203.0.113.9" },
    body: JSON.stringify(body),
  });

Deno.test("a report is filed with its attachment linked, and the issue comes back", async () => {
  const calls: string[] = [];
  const deps = { ...dependencies(await testConfig(), pretendGitHub(calls)), log: () => {} };
  const response = await handle(post(report()), deps);
  equal(response.status, 201);
  equal(await response.json(), { issue_number: 42, html_url: "https://example.com/issues/42" });
  assert(calls.includes("PUT repos/team/feedback/contents/.beacon/attachments/BN-ABC123/shot.png"), calls.join("\n"));
});

Deno.test("with no installation id set, the repository's installation is looked up", async () => {
  const calls: string[] = [];
  const { GITHUB_INSTALLATION_ID: _, ...noInstallation } = base;
  const config = loadConfig(env({
    ...noInstallation, GITHUB_APP_PRIVATE_KEY: await testKeyPEM(), TARGET_OWNER: "team", TARGET_REPO: "found",
  }));
  const deps = { ...dependencies(config, pretendGitHub(calls)), log: () => {} };
  equal((await handle(post(report()), deps)).status, 201);
  assert(calls.includes("POST app/installations/999/access_tokens"), calls.join("\n"));
});

Deno.test("a wrong token files nothing", async () => {
  const calls: string[] = [];
  const deps = { ...dependencies(await testConfig(), pretendGitHub(calls)), log: () => {} };
  const response = await handle(post(report(), "guess"), deps);
  equal(response.status, 401);
  equal(calls.length, 0);
});

Deno.test("one device sending too much is slowed down", async () => {
  const config = { ...await testConfig(), perDevicePerHour: 1 };
  const deps = { ...dependencies(config, pretendGitHub([])), log: () => {} };
  equal((await handle(post(report()), deps)).status, 201);
  const second = await handle(post(report()), deps);
  equal(second.status, 429);
  equal(await second.json(), { error: ANSWERS.tooMany });
});
