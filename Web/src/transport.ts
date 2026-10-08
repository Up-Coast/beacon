import type { Payload } from "./types";

/** Sends a finished report to the Beacon relay, the same endpoint and payload the Mac and iPhone apps use
 * (RelayTransport in Sources/BeaconGitHub/Transports.swift). The token is a door key, not a GitHub credential:
 * it ships to the browser, and the relay limits who may use it by address and by origin. */

export type SendResult = { ok: true } | { ok: false; reason: "unreachable" | "refused" | "too-many" };

export interface RelayConfig {
  url: string;
  token?: string;
}

export async function sendToRelay(
  relay: RelayConfig,
  payload: Payload,
  fetchFn: typeof fetch = fetch,
): Promise<SendResult> {
  let res: Response;
  try {
    res = await fetchFn(relay.url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(relay.token ? { authorization: `Bearer ${relay.token}` } : {}),
      },
      body: JSON.stringify(payload),
    });
  } catch {
    return { ok: false, reason: "unreachable" };
  }
  if (res.ok) return { ok: true };
  return { ok: false, reason: res.status === 429 ? "too-many" : "refused" };
}
