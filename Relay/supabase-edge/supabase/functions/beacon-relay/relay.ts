// Beacon's reference relay: the app posts a finished report here, and the
// relay files it into a private GitHub repository with a GitHub App.
//
// The reporter has no GitHub account and never learns where the report
// goes, so every message this file can return to the app speaks of "the
// report" and "the team", never of GitHub. Those messages are in ANSWERS.
//
// How a report is filed mirrors GitHubIssueTransport in
// Sources/BeaconGitHub/Transports.swift, which is the reference: the same
// attachments branch and path layout, the same link rewriting, the same
// note when the files cannot be committed. Swift and TypeScript cannot
// share code, so if one changes, change the other.

/** Every sentence the app may show the reporter. */
export const ANSWERS = {
  unauthorized: "This app can't send reports right now.",
  unrouted: "This app can't send reports right now.",
  unreadable: "The report couldn't be read. Please try sending it again.",
  forbiddenOrigin: "This site can't send reports right now.",
  tooLarge: "The report is too large to send. Removing the largest attachment usually does it.",
  tooMany: "A lot of reports have come from here just now. Please try again in a little while.",
  undelivered: "The report couldn't be delivered just now.",
} as const;

/**
 * The same limit RelayTransport checks before sending: 30 MiB of base64.
 * Supabase gives a request 256 MB. The relay holds the raw bytes, the
 * decoded text and the parsed report at once, about three copies, plus
 * one attachment re-encoded for GitHub: 30 MiB keeps that near 120 MB.
 */
export const MAX_ATTACHMENT_BASE64 = 30 * 1024 * 1024;
/** Room for the report's words and the JSON around the attachments. */
export const MAX_REQUEST_BYTES = MAX_ATTACHMENT_BASE64 + 1024 * 1024;
/** GitHub's issue body limit is 65,536 characters; up to 30 attachment links are added later. */
const MAX_BODY = 50_000;
/** The labels the relay passes on, so a request cannot make the GitHub App create new ones. */
const FIXED_LABELS = new Set([
  "beacon",
  "type:bug", "type:feature-request", "type:change-request", "type:feedback",
  "impact:blocked", "impact:slowed", "impact:irritating", "impact:noticed",
]);
/** An area label is `area:` and the indexer's id: lowercase words joined by hyphens. */
const AREA_LABEL = /^area:[a-z0-9][a-z0-9-]{0,44}$/;
/** A bundle identifier, or empty when the app didn't say. */
const BUNDLE_ID = /^([A-Za-z0-9][A-Za-z0-9.-]{0,254})?$/;
const ATTACHMENT_BRANCH = "beacon-attachments";
const GITHUB_API = "https://api.github.com";

// MARK: Configuration

export interface Target {
  owner: string;
  repo: string;
  installationId: string;
}

export interface Config {
  appToken: string;
  appId: string;
  privateKey: string;
  /** Empty when GITHUB_INSTALLATION_ID is not set. */
  installationId: string;
  fallback?: { owner: string; repo: string };
  /** Bundle id to target. A Map, so a bundle id like `__proto__` finds nothing. */
  targets: Map<string, Target>;
  perIPPerHour: number;
  perDevicePerHour: number;
  /** Websites allowed to send from a browser (ALLOWED_ORIGINS, comma separated). Empty: no browser may. */
  allowedOrigins?: string[];
}

/** Reads the configuration, or names every setting that is missing. */
export function loadConfig(env: (name: string) => string | undefined): Config {
  const required = ["BEACON_APP_TOKEN", "GITHUB_APP_ID", "GITHUB_APP_PRIVATE_KEY"];
  const missing = required.filter((name) => !env(name));
  if (missing.length) throw new Error(`missing settings: ${missing.join(", ")}`);
  // Optional: left out, the relay asks GitHub which installation covers each repository.
  const installationId = env("GITHUB_INSTALLATION_ID") ?? "";

  const targets = new Map<string, Target>();
  const raw = env("TARGETS");
  if (raw) {
    // {"com.example.app": "owner/repo"} or
    // {"com.example.app": {"repo": "owner/repo", "installation": "123"}}
    for (const [bundleID, value] of Object.entries(JSON.parse(raw) as Record<string, unknown>)) {
      const spec = typeof value === "string" ? { repo: value } : value as { repo?: string; installation?: string };
      const [owner, repo] = (spec.repo ?? "").split("/");
      if (!owner || !repo) throw new Error(`TARGETS: "${bundleID}" needs "owner/repo"`);
      targets.set(bundleID, { owner, repo, installationId: String(spec.installation ?? installationId) });
    }
  }
  const owner = env("TARGET_OWNER"), repo = env("TARGET_REPO");
  if (!targets.size && !(owner && repo)) {
    throw new Error("missing settings: TARGET_OWNER and TARGET_REPO, or TARGETS");
  }
  return {
    appToken: env("BEACON_APP_TOKEN")!,
    appId: env("GITHUB_APP_ID")!,
    privateKey: env("GITHUB_APP_PRIVATE_KEY")!.replace(/\\n/g, "\n"),
    installationId,
    fallback: owner && repo ? { owner, repo } : undefined,
    targets,
    perIPPerHour: Number(env("RATE_LIMIT_PER_IP") ?? 30),
    perDevicePerHour: Number(env("RATE_LIMIT_PER_DEVICE") ?? 10),
    allowedOrigins: (env("ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((o) => o.trim().replace(/\/$/, ""))
      .filter(Boolean),
  };
}

/** Where a report from this app is filed: its own entry, or the default. */
export function routeFor(app: string, config: Config): Target | null {
  const own = config.targets.get(app);
  if (own) return own;
  return config.fallback ? { ...config.fallback, installationId: config.installationId } : null;
}

// MARK: The app token

/** Compares the request's bearer token with the secret in constant time. */
export function tokenMatches(header: string | null, expected: string): boolean {
  const presented = new TextEncoder().encode(header?.startsWith("Bearer ") ? header.slice(7) : "");
  const wanted = new TextEncoder().encode(expected);
  let difference = presented.length ^ wanted.length;
  for (let i = 0; i < wanted.length; i++) difference |= (presented[i] ?? 0) ^ wanted[i];
  return wanted.length > 0 && difference === 0;
}

// MARK: The report

export interface Attachment {
  filename: string;
  base64: string;
}

export interface Payload {
  title: string;
  body: string;
  labels: string[];
  reference: string;
  account: string;
  app: string;
  contact?: string;
  attachments: Attachment[];
}

const isString = (value: unknown, max: number, min = 0): value is string =>
  typeof value === "string" && value.length >= min && value.length <= max;

/** Checks the report's shape and sizes. Returns the reason it is refused, or the report. */
export function validatePayload(raw: unknown): { payload: Payload } | { error: string; status: number } {
  const unreadable = { error: ANSWERS.unreadable, status: 400 };
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) return unreadable;
  const r = raw as Record<string, unknown>;
  if (!isString(r.title, 256, 1) || !isString(r.body, MAX_BODY, 1)) return unreadable;
  if (!isString(r.reference, 9) || !/^BN-[0-9A-F]{6}$/.test(r.reference)) return unreadable;
  if (!isString(r.account, 200, 1)) return unreadable;
  if (!isString(r.app ?? "", 255) || !BUNDLE_ID.test((r.app as string) ?? "")) return unreadable;
  if (r.contact !== undefined && !isString(r.contact, 300)) return unreadable;
  const labels = r.labels ?? [];
  if (!Array.isArray(labels) || labels.length > 20 || !labels.every((l) => isString(l, 50, 1))) return unreadable;
  const attachments = r.attachments ?? [];
  if (!Array.isArray(attachments) || attachments.length > 30) return unreadable;
  let total = 0;
  for (const a of attachments as Record<string, unknown>[]) {
    if (!isString(a?.filename, 255, 1) || typeof a?.base64 !== "string") return unreadable;
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(a.base64)) return unreadable;
    total += a.base64.length;
  }
  if (total > MAX_ATTACHMENT_BASE64) return { error: ANSWERS.tooLarge, status: 413 };
  return {
    payload: {
      title: r.title, body: r.body, labels: allowedLabels(labels as string[]), reference: r.reference,
      account: r.account, app: (r.app as string) ?? "", contact: r.contact as string | undefined,
      attachments: attachments as Attachment[],
    },
  };
}

/** Beacon's own labels only, as IssueRenderer.Labels in Swift makes them. Anything else is dropped. */
export function allowedLabels(labels: string[]): string[] {
  return [...new Set(labels.filter((label) => FIXED_LABELS.has(label) || AREA_LABEL.test(label)))];
}

/** A filename made safe for a repository path, as ReportArchive.safeFilename does. */
export function safeFilename(name: string): string {
  const cleaned = name.replace(/[^A-Za-z0-9._\- ]/g, "_").trim().replace(/^\.+/, "_");
  return cleaned ? cleaned.slice(0, 120) : "attachment";
}

// MARK: Rate limits

/**
 * How many reports one key may send in a rolling hour, kept in memory.
 * Stale keys are dropped as it goes, and it never holds more than
 * `maxKeys`: past that, the keys seen longest ago are forgotten first.
 */
export class RateLimiter {
  private seen = new Map<string, number[]>();
  private calls = 0;
  constructor(private perHour: number, private now: () => number = Date.now, private maxKeys = 10_000) {}

  allow(key: string): boolean {
    const since = this.now() - 3_600_000;
    if (++this.calls % 100 === 0) this.prune(since);
    const recent = (this.seen.get(key) ?? []).filter((t) => t > since);
    this.seen.delete(key); // re-inserted below, so the Map stays in order of last use
    const allowed = recent.length < this.perHour;
    if (allowed) recent.push(this.now());
    this.seen.set(key, recent);
    while (this.seen.size > this.maxKeys) this.seen.delete(this.seen.keys().next().value!);
    return allowed;
  }

  get size(): number {
    return this.seen.size;
  }

  private prune(since: number) {
    for (const [key, times] of this.seen) {
      if (!times.some((t) => t > since)) this.seen.delete(key);
    }
  }
}

// MARK: GitHub App authentication

const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

/** DER length bytes. */
function derLength(n: number): number[] {
  if (n < 0x80) return [n];
  const bytes: number[] = [];
  for (let v = n; v > 0; v >>= 8) bytes.unshift(v & 0xff);
  return [0x80 | bytes.length, ...bytes];
}

/** GitHub hands out PKCS#1 keys; WebCrypto takes PKCS#8. Wrap the one in the other. */
function pkcs8From(pem: string) {
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----|\s/g, "")), (c) => c.charCodeAt(0));
  if (!pem.includes("BEGIN RSA PRIVATE KEY")) return der;
  const algorithm = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00];
  const inner = [0x02, 0x01, 0x00, ...algorithm, 0x04, ...derLength(der.length), ...der];
  return new Uint8Array([0x30, ...derLength(inner.length), ...inner]);
}

/** The app's JWT: RS256, issued a minute ago for clock drift, valid nine minutes. */
export async function appJWT(appId: string, privateKey: string, nowSeconds: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8", pkcs8From(privateKey), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const encode = (value: unknown) => base64url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({ iat: nowSeconds - 60, exp: nowSeconds + 540, iss: appId })}`;
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  return `${unsigned}.${base64url(new Uint8Array(signature))}`;
}

const cachedTokens = new Map<string, { token: string; expires: number }>();
const foundInstallations = new Map<string, string>();

/** The installation that covers a repository, when the settings don't name one. */
export async function installationFor(
  target: Target, config: Config, fetchFn: typeof fetch, now = Date.now,
): Promise<string> {
  if (target.installationId) return target.installationId;
  const key = `${target.owner}/${target.repo}`;
  if (!foundInstallations.has(key)) {
    const jwt = await appJWT(config.appId, config.privateKey, Math.floor(now() / 1000));
    const found = await gitHub(fetchFn, jwt, "GET", `repos/${key}/installation`);
    foundInstallations.set(key, String(found.id));
  }
  return foundInstallations.get(key)!;
}

/** An installation token, reused until five minutes before it expires. */
export async function installationToken(
  installationId: string, config: Config, fetchFn: typeof fetch, now = Date.now,
): Promise<string> {
  const cached = cachedTokens.get(installationId);
  if (cached && cached.expires - 300_000 > now()) return cached.token;
  const jwt = await appJWT(config.appId, config.privateKey, Math.floor(now() / 1000));
  const answer = await gitHub(fetchFn, jwt, "POST", `app/installations/${installationId}/access_tokens`);
  cachedTokens.set(installationId, { token: answer.token, expires: Date.parse(answer.expires_at) });
  return answer.token;
}

// deno-lint-ignore no-explicit-any
type Json = any;

class GitHubError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

async function gitHub(fetchFn: typeof fetch, token: string, method: string, path: string, body?: unknown): Promise<Json> {
  const response = await fetchFn(`${GITHUB_API}/${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "beacon-relay",
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const parsed = await response.json().catch(() => ({}));
  if (!response.ok) throw new GitHubError(response.status, parsed.message ?? response.statusText);
  return parsed;
}

// MARK: Filing, as GitHubIssueTransport does

const ATTACHMENTS_REFUSED_NOTE = `

> [!NOTE]
> The reporter attached files, but the relay couldn't add them to this repository, \
so none are linked here. The files are kept on the reporter's device.
`;

/** Make sure the attachments branch exists, creating it from the default branch's head. */
async function ensureBranch(fetchFn: typeof fetch, token: string, repoPath: string) {
  try {
    await gitHub(fetchFn, token, "GET", `${repoPath}/git/ref/heads/${ATTACHMENT_BRANCH}`);
    return;
  } catch (error) {
    if (!(error instanceof GitHubError) || error.status !== 404) throw error;
  }
  const repo = await gitHub(fetchFn, token, "GET", repoPath);
  const head = await gitHub(fetchFn, token, "GET", `${repoPath}/git/ref/heads/${repo.default_branch ?? "main"}`);
  await gitHub(fetchFn, token, "POST", `${repoPath}/git/refs`, {
    ref: `refs/heads/${ATTACHMENT_BRANCH}`, sha: head.object.sha,
  });
}

/**
 * Commit one attachment and return its link. A report sent again, after a
 * send that committed its files but failed before the issue, finds them
 * already there: GitHub answers 422 without the file's sha, and the file
 * already committed is used as it is.
 */
async function putAttachment(
  fetchFn: typeof fetch, token: string, contentsPath: string, reference: string, base64: string,
): Promise<string | undefined> {
  try {
    const put = await gitHub(fetchFn, token, "PUT", contentsPath, {
      message: `Beacon attachment for ${reference}`, content: base64, branch: ATTACHMENT_BRANCH,
    });
    return put?.content?.html_url;
  } catch (error) {
    if (!(error instanceof GitHubError) || error.status !== 422) throw error;
    const existing = await gitHub(fetchFn, token, "GET", `${contentsPath}?ref=${ATTACHMENT_BRANCH}`);
    return existing?.html_url;
  }
}

/** Attachments first, then the issue that links to them. */
export async function fileReport(
  payload: Payload, target: Target, token: string, fetchFn: typeof fetch,
): Promise<{ issue_number: number; html_url: string }> {
  const repoPath = `repos/${target.owner}/${target.repo}`;
  let body = payload.body;
  if (payload.attachments.length) {
    try {
      await ensureBranch(fetchFn, token, repoPath);
      const used = new Set<string>();
      for (const attachment of payload.attachments) {
        let name = safeFilename(attachment.filename);
        while (used.has(name)) name = `_${name}`;
        used.add(name);
        const path = `.beacon/attachments/${payload.reference}/${encodeURIComponent(name)}`;
        const url = await putAttachment(fetchFn, token, `${repoPath}/contents/${path}`, payload.reference, attachment.base64);
        if (url) body = body.replaceAll("- `" + attachment.filename + "`", "- [`" + attachment.filename + "`](" + url + ")");
      }
    } catch (error) {
      if (!(error instanceof GitHubError) || (error.status !== 403 && error.status !== 404)) throw error;
      body += ATTACHMENTS_REFUSED_NOTE;
    }
  }
  const issue = await gitHub(fetchFn, token, "POST", `${repoPath}/issues`, {
    title: payload.title, body, labels: payload.labels,
  });
  return { issue_number: issue.number, html_url: issue.html_url };
}

// MARK: The request

export interface Dependencies {
  config: Config;
  fetchFn: typeof fetch;
  byIP: RateLimiter;
  byDevice: RateLimiter;
  log?: (message: string) => void;
}

const answer = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

export function dependencies(config: Config, fetchFn: typeof fetch = fetch): Dependencies {
  return {
    config, fetchFn,
    byIP: new RateLimiter(config.perIPPerHour),
    byDevice: new RateLimiter(config.perDevicePerHour),
    log: console.error,
  };
}

/**
 * The caller's address. The first X-Forwarded-For entries are whatever the
 * caller wrote; the last is the one the platform's own proxy added.
 */
export function clientAddress(request: Request): string {
  const hops = (request.headers.get("X-Forwarded-For") ?? "").split(",").map((hop) => hop.trim());
  return hops.at(-1) || "unknown";
}

/** The request body as text, or null once it passes `limit` bytes. */
export async function readCapped(request: Request, limit: number): Promise<string | null> {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > limit) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return new TextDecoder().decode(bytes);
}

/** The headers a browser needs to read an answer. A native app sends no Origin and never needs them. */
function corsHeaders(origin: string): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

/** Browser support for Beacon on the web (Web/ in this repository). A request that carries an Origin is a
 * browser's; it is answered only for a site listed in ALLOWED_ORIGINS, so the app token alone, lifted from a
 * page's source, cannot be used from some other site. Requests without an Origin are native apps and unchanged. */
export async function handle(request: Request, deps: Dependencies): Promise<Response> {
  const origin = request.headers.get("Origin");
  if (!origin) return await handleReport(request, deps);
  const allowed = (deps.config.allowedOrigins ?? []).includes(origin.replace(/\/$/, ""));
  if (!allowed) return answer(403, { error: ANSWERS.forbiddenOrigin });
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(origin) });
  const response = await handleReport(request, deps);
  for (const [name, value] of Object.entries(corsHeaders(origin))) response.headers.set(name, value);
  return response;
}

async function handleReport(request: Request, deps: Dependencies): Promise<Response> {
  if (request.method !== "POST") return answer(405, { error: ANSWERS.unreadable });
  if (!tokenMatches(request.headers.get("Authorization"), deps.config.appToken)) {
    return answer(401, { error: ANSWERS.unauthorized });
  }
  if (Number(request.headers.get("Content-Length") ?? 0) > MAX_REQUEST_BYTES) {
    return answer(413, { error: ANSWERS.tooLarge });
  }
  if (!deps.byIP.allow(clientAddress(request))) return answer(429, { error: ANSWERS.tooMany });

  // Read with a running count: a request without Content-Length, or one
  // that lies in it, is cut off at the limit instead of filling memory.
  const text = await readCapped(request, MAX_REQUEST_BYTES);
  if (text === null) return answer(413, { error: ANSWERS.tooLarge });
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return answer(400, { error: ANSWERS.unreadable });
  }
  const checked = validatePayload(raw);
  if ("error" in checked) return answer(checked.status, { error: checked.error });
  const { payload } = checked;
  if (!deps.byDevice.allow(payload.account)) return answer(429, { error: ANSWERS.tooMany });

  const target = routeFor(payload.app, deps.config);
  if (!target) {
    deps.log?.(`no target for app "${payload.app}"`);
    return answer(404, { error: ANSWERS.unrouted });
  }
  try {
    const installation = await installationFor(target, deps.config, deps.fetchFn);
    const token = await installationToken(installation, deps.config, deps.fetchFn);
    return answer(201, await fileReport(payload, target, token, deps.fetchFn));
  } catch (error) {
    deps.log?.(`filing ${payload.reference} failed: ${error instanceof Error ? error.message : error}`);
    return answer(502, { error: ANSWERS.undelivered });
  }
}
