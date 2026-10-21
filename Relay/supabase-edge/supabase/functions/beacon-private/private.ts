// Stores data an app sealed to its owner's key, away from GitHub. The app
// encrypts on the device, so this function and the bucket only ever hold
// ciphertext and there is no route back out through the relay: the owner
// reads the bucket locally with their own key. Everything the function does
// is here; index.ts reads the settings and serves.

import { clientAddress, RateLimiter, readCapped, tokenMatches } from "../beacon-relay/relay.ts";

/** The most a sealed message may be, in bytes. The bucket enforces the same. */
export const MAX_SEALED_BYTES = 64 * 1024;

/** The request body limit: the sealed bytes as base64, plus the JSON around them. */
export const MAX_REQUEST_BYTES = Math.ceil(MAX_SEALED_BYTES * 4 / 3) + 512;

/** The bucket sealed messages go to when `PRIVATE_BUCKET` is not set. */
export const DEFAULT_BUCKET = "beacon-private";

const ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const APP = /^[A-Za-z0-9][A-Za-z0-9.-]{0,254}$/;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

export const ANSWERS = {
  unauthorized: "Not authorised.",
  method: "Send a POST.",
  tooMany: "Too many reports from here. Try again later.",
  tooLarge: "That is larger than this accepts.",
  invalid: "That is not a sealed report.",
  stored: "Stored.",
  exists: "Already stored.",
  failed: "Could not store it.",
} as const;

export interface Config {
  /** The token the app sends, compared in constant time. Not a Supabase credential. */
  appToken: string;
  /** The project's address, e.g. https://abc.supabase.co. */
  supabaseUrl: string;
  /** The project's secret key; stays inside this function. */
  secretKey: string;
  /** Messages one address may store in an hour. */
  perIp: number;
  /** The private bucket. */
  bucket: string;
  /** The apps allowed to store here (bundle identifiers); empty allows any. */
  apps: Set<string>;
}

export function loadConfig(env: (name: string) => string | undefined): Config {
  const need = (name: string) => {
    const value = env(name);
    if (!value) throw new Error(`${name} is not set`);
    return value;
  };
  const perIp = Number(env("PRIVATE_RATE_LIMIT_PER_IP") ?? 30);
  return {
    appToken: need("BEACON_PRIVATE_TOKEN"),
    supabaseUrl: need("SUPABASE_URL").replace(/\/+$/, ""),
    secretKey: need("SUPABASE_SERVICE_ROLE_KEY"),
    perIp: Number.isFinite(perIp) && perIp > 0 ? perIp : 30,
    bucket: env("PRIVATE_BUCKET") || DEFAULT_BUCKET,
    apps: new Set((env("PRIVATE_APPS") ?? "").split(",").map((app) => app.trim()).filter(Boolean)),
  };
}

/** Whether a message was stored or one already sat under that id. */
export type StoreResult = "stored" | "exists";

export interface Dependencies {
  config: Config;
  limiter: RateLimiter;
  store: (path: string, bytes: Uint8Array) => Promise<StoreResult>;
}

/** Writes the bytes to the private bucket at `path`; never replaces an existing object. */
export function storeInBucket(config: Config, fetchFn: typeof fetch = fetch) {
  return async (path: string, bytes: Uint8Array): Promise<StoreResult> => {
    const response = await fetchFn(`${config.supabaseUrl}/storage/v1/object/${config.bucket}/${path}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.secretKey}`,
        "Content-Type": "application/octet-stream",
        "x-upsert": "false",
      },
      body: bytes.slice(),
    });
    if (response.ok) return "stored";
    // The storage API answers 400 or 409 for an object that is already there.
    const text = await response.text();
    if (response.status === 409 || /already exists|Duplicate/i.test(text)) return "exists";
    throw new Error(`storage answered ${response.status}`);
  };
}

export function dependencies(config: Config, fetchFn: typeof fetch = fetch): Dependencies {
  return { config, limiter: new RateLimiter(config.perIp), store: storeInBucket(config, fetchFn) };
}

const json = (status: number, message: string) =>
  new Response(JSON.stringify({ message }), { status, headers: { "Content-Type": "application/json" } });

/** Decodes standard base64 to bytes, or null when it is not valid. */
function decode(text: string): Uint8Array | null {
  if (!BASE64.test(text) || text.length % 4 !== 0) return null;
  try {
    return Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

export async function handle(request: Request, deps: Dependencies): Promise<Response> {
  if (request.method !== "POST") return json(405, ANSWERS.method);
  if (!tokenMatches(request.headers.get("Authorization"), deps.config.appToken)) {
    return json(401, ANSWERS.unauthorized);
  }
  if (!deps.limiter.allow(clientAddress(request))) return json(429, ANSWERS.tooMany);

  const text = await readCapped(request, MAX_REQUEST_BYTES);
  if (text === null) return json(413, ANSWERS.tooLarge);

  let body: { id?: unknown; app?: unknown; ciphertext?: unknown };
  try {
    body = JSON.parse(text);
  } catch {
    return json(400, ANSWERS.invalid);
  }
  if (typeof body.id !== "string" || !ID.test(body.id)) return json(400, ANSWERS.invalid);
  if (typeof body.app !== "string" || !APP.test(body.app)) return json(400, ANSWERS.invalid);
  if (deps.config.apps.size > 0 && !deps.config.apps.has(body.app)) return json(403, ANSWERS.unauthorized);
  if (typeof body.ciphertext !== "string") return json(400, ANSWERS.invalid);
  const bytes = decode(body.ciphertext);
  // A sealed message is at least the 32-byte encapsulated key and a 16-byte tag.
  if (!bytes || bytes.length < 48) return json(400, ANSWERS.invalid);
  if (bytes.length > MAX_SEALED_BYTES) return json(413, ANSWERS.tooLarge);

  try {
    const result = await deps.store(`${body.app}/${body.id}.bin`, bytes);
    return result === "stored" ? json(200, ANSWERS.stored) : json(409, ANSWERS.exists);
  } catch (error) {
    console.error(`beacon-private: ${error instanceof Error ? error.message : String(error)}`);
    return json(502, ANSWERS.failed);
  }
}
