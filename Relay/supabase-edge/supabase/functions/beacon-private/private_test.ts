// The private store's checks, with no network: run `deno test` in Relay/supabase-edge.

import { RateLimiter } from "../beacon-relay/relay.ts";
import {
  ANSWERS, type Config, type Dependencies, handle, loadConfig, MAX_SEALED_BYTES, storeInBucket,
} from "./private.ts";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

const config: Config = {
  appToken: "app-token",
  supabaseUrl: "https://x.supabase.co",
  secretKey: "secret",
  perIp: 2,
  bucket: "beacon-private",
  apps: new Set(),
};
const APP = "com.example.harbour";
const EVENT = "11111111-2222-3333-4444-555555555555";
const sealed = (length = 64) => btoa(String.fromCharCode(...new Uint8Array(length).fill(7)));

function deps(store: Dependencies["store"] = () => Promise.resolve("stored")): Dependencies {
  return { config, limiter: new RateLimiter(config.perIp), store };
}

function post(body: unknown, headers: Record<string, string> = {}, method = "POST") {
  return new Request("https://x/functions/v1/beacon-private", {
    method,
    headers: { Authorization: "Bearer app-token", "X-Forwarded-For": "1.2.3.4", ...headers },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}

Deno.test("stores a sealed message and answers 200", async () => {
  const seen: [string, number][] = [];
  const response = await handle(
    post({ id: EVENT, app: APP, ciphertext: sealed() }),
    deps((id, bytes) => (seen.push([id, bytes.length]), Promise.resolve("stored"))),
  );
  assert(response.status === 200);
  assert(JSON.stringify(seen) === JSON.stringify([[`${APP}/${EVENT}.bin`, 64]]));
});

Deno.test("refuses a wrong or missing token, and anything but POST", async () => {
  assert((await handle(post({}, { Authorization: "Bearer nope" }), deps())).status === 401);
  assert((await handle(post({}, { Authorization: "" }), deps())).status === 401);
  assert((await handle(post({}, {}, "GET"), deps())).status === 405);
});

Deno.test("refuses a body that is not a sealed report", async () => {
  const d = deps(() => Promise.reject(new Error("must not store")));
  for (
    const body of [
      { id: "../etc/passwd", app: APP, ciphertext: sealed() },
      { id: "ABCDEF12-2222-3333-4444-555555555555", app: APP, ciphertext: sealed() },
      { id: EVENT, app: "../other", ciphertext: sealed() },
      { id: EVENT, ciphertext: sealed() },
      { id: EVENT, app: APP, ciphertext: "not base64!" },
      { id: EVENT, app: APP, ciphertext: sealed(10) },
      { id: EVENT, app: APP },
      {},
    ]
  ) {
    const d2 = { ...d, limiter: new RateLimiter(100) };
    assert((await handle(post(body), d2)).status === 400, JSON.stringify(body).slice(0, 60));
  }
});

Deno.test("refuses a message over the size limit", async () => {
  const response = await handle(post({ id: EVENT, app: APP, ciphertext: sealed(MAX_SEALED_BYTES + 1) }), deps());
  assert(response.status === 413);
});

Deno.test("answers 409 and does not replace a record that already exists", async () => {
  const response = await handle(post({ id: EVENT, app: APP, ciphertext: sealed() }), deps(() => Promise.resolve("exists")));
  assert(response.status === 409);
});

Deno.test("limits one address per hour", async () => {
  const d = deps();
  assert((await handle(post({ id: EVENT, app: APP, ciphertext: sealed() }), d)).status === 200);
  assert((await handle(post({ id: EVENT, app: APP, ciphertext: sealed() }), d)).status === 200);
  assert((await handle(post({ id: EVENT, app: APP, ciphertext: sealed() }), d)).status === 429);
});

Deno.test("a storage failure is a 502 that does not repeat the cause", async () => {
  const response = await handle(
    post({ id: EVENT, app: APP, ciphertext: sealed() }),
    deps(() => Promise.reject(new Error("storage answered 500 secret-detail"))),
  );
  assert(response.status === 502);
  assert(!(await response.text()).includes("secret-detail"));
});

Deno.test("the bucket write never upserts and treats an existing object as stored already", async () => {
  let call: { url: string; init: RequestInit } | undefined;
  const fake = (url: string | URL | Request, init?: RequestInit) => {
    call = { url: String(url), init: init! };
    return Promise.resolve(new Response('{"error":"Duplicate"}', { status: 409 }));
  };
  const result = await storeInBucket(config, fake as typeof fetch)(`${APP}/${EVENT}.bin`, new Uint8Array(60));
  assert(result === "exists");
  assert(call!.url === `https://x.supabase.co/storage/v1/object/beacon-private/${APP}/${EVENT}.bin`);
  assert((call!.init.headers as Record<string, string>)["x-upsert"] === "false");
});

Deno.test("refuses an app not on the list when a list is set", async () => {
  const d = { ...deps(), config: { ...config, apps: new Set(["com.example.other"]) } };
  assert((await handle(post({ id: EVENT, app: APP, ciphertext: sealed() }), d)).status === 403);
});

Deno.test("is not set up without its token, address and key", () => {
  let failed = false;
  try {
    loadConfig(() => undefined);
  } catch {
    failed = true;
  }
  assert(failed);
  assert(ANSWERS.unauthorized.length > 0);
});
