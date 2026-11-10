import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MAX_ATTACHMENT_BASE64 } from "../../supabase-edge/supabase/functions/beacon-relay/relay.ts";
import { relayHandler, settingsFrom } from "../src/host.ts";
import { APP, listen, post, pretendGitHub, secret } from "./support.ts";

let account = 0;
const report = (extra: Record<string, unknown> = {}) => ({
  title: "Crash", body: "It broke", labels: ["beacon", "type:bug"], reference: "BN-ABC123",
  account: `device-${account++}`, app: APP, attachments: [], ...extra,
});

describe("the relay on the Firebase host", () => {
  let server: Awaited<ReturnType<typeof listen>>;
  beforeAll(async () => {
    server = await listen(() => relayHandler(secret({ RATE_LIMIT_PER_IP: 1 }), pretendGitHub));
  });
  afterAll(() => server.close());

  it("files a valid report and answers 201 with the issue", async () => {
    const response = await post(server.url, report(), { "X-Forwarded-For": "198.51.100.1" });
    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({ issue_number: 42, html_url: "https://example.com/issues/42" });
  });

  it("counts two callers with different addresses separately", async () => {
    const send = (address: string) => post(server.url, report(), { "X-Forwarded-For": address });
    expect((await send("198.51.100.2")).status).toBe(201);
    expect((await send("198.51.100.2")).status).toBe(429);
    expect((await send("198.51.100.3")).status).toBe(201);
  });

  it("refuses a wrong token", async () => {
    const response = await post(server.url, report(), { Authorization: "Bearer guess", "X-Forwarded-For": "198.51.100.4" });
    expect(response.status).toBe(401);
  });

  it("answers a preflight from an allowed origin with 204 and the CORS headers", async () => {
    const response = await fetch(server.url, { method: "OPTIONS", headers: { Origin: "https://site.test" } });
    expect(response.status).toBe(204);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe("https://site.test");
    expect(response.headers.get("Access-Control-Allow-Methods")).toContain("POST");
  });

  it("answers a preflight from another origin with 403", async () => {
    const response = await fetch(server.url, { method: "OPTIONS", headers: { Origin: "https://evil.test" } });
    expect(response.status).toBe(403);
  });

  it("accepts an attachment of 30 MiB encoded", async () => {
    const attachments = [{ filename: "clip.mov", base64: "A".repeat(MAX_ATTACHMENT_BASE64) }];
    const response = await post(server.url, report({ attachments }), { "X-Forwarded-For": "198.51.100.5" });
    expect(response.status).toBe(201);
  }, 60_000);

  it("is not set up without its settings, and says so with 503", async () => {
    const bare = await listen(() => relayHandler("{}", pretendGitHub));
    try {
      expect((await post(bare.url, report())).status).toBe(503);
    } finally {
      await bare.close();
    }
  });
});

describe("the settings secret", () => {
  it("hands back text for text and JSON for nested objects, and nothing for a missing name", () => {
    const get = settingsFrom(JSON.stringify({ A: "x", TARGETS: { app: "o/r" }, N: 5 }));
    expect(get("A")).toBe("x");
    expect(get("TARGETS")).toBe('{"app":"o/r"}');
    expect(get("N")).toBe("5");
    expect(get("MISSING")).toBeUndefined();
  });
});
