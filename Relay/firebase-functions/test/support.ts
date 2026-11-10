// Shared by the host tests: a real HTTP server around a shared handler, and settings.

import { generateKeyPairSync } from "node:crypto";
import { createServer, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import { serve, type Handler } from "../src/web.ts";

export const TOKEN = "test-app-token";
export const APP = "com.example.harbour";

const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });

/** The secret as a deployer writes it: the key's line breaks as `\n`, TARGETS an object. */
export function secret(extra: Record<string, unknown> = {}): string {
  return JSON.stringify({
    BEACON_APP_TOKEN: TOKEN,
    BEACON_PRIVATE_TOKEN: TOKEN,
    GITHUB_APP_ID: "1",
    GITHUB_APP_PRIVATE_KEY: privateKey.export({ type: "pkcs8", format: "pem" }).toString().replaceAll("\n", "\\n"),
    GITHUB_INSTALLATION_ID: "2",
    TARGETS: { [APP]: "team/feedback" },
    ALLOWED_ORIGINS: "https://site.test",
    ...extra,
  });
}

/** A GitHub that takes everything and files issue 42. */
export const pretendGitHub: typeof fetch = async (input) => {
  const url = String(input);
  const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status });
  if (url.endsWith("/access_tokens")) return json(201, { token: "t", expires_at: "2999-01-01T00:00:00Z" });
  if (url.includes("/git/ref/heads/beacon-attachments")) return json(200, { object: { sha: "abc" } });
  if (url.includes("/contents/")) return json(201, { content: { html_url: "https://example.com/file" } });
  if (url.endsWith("/issues")) return json(201, { number: 42, html_url: "https://example.com/issues/42" });
  return json(404, { message: "Not Found" });
};

/** Serves `build()`'s handler on a free local port, the way Firebase serves a function. */
export async function listen(build: () => Handler): Promise<{ url: string; close: () => Promise<void> }> {
  const server: Server = createServer(serve(build, { error: "not set up" }));
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  return {
    url: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
    close: () => new Promise((resolve) => server.close(() => resolve())),
  };
}

export const post = (url: string, body: unknown, headers: Record<string, string> = {}) =>
  fetch(url, {
    method: "POST", body: typeof body === "string" ? body : JSON.stringify(body),
    headers: { Authorization: `Bearer ${TOKEN}`, ...headers },
  });
