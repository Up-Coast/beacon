import type { Payload } from "./types";
/** Sends a finished report to the Beacon relay, the same endpoint and payload the Mac and iPhone apps use
 * (RelayTransport in Sources/BeaconGitHub/Transports.swift). The token is a door key, not a GitHub credential:
 * it ships to the browser, and the relay limits who may use it by address and by origin. */
export type SendResult = {
    ok: true;
} | {
    ok: false;
    reason: "unreachable" | "refused" | "too-many";
};
export interface RelayConfig {
    url: string;
    token?: string;
}
export declare function sendToRelay(relay: RelayConfig, payload: Payload, fetchFn?: typeof fetch): Promise<SendResult>;
