// What the two functions are made of, apart from the Firebase wrappers in index.ts, so
// tests can build them with a pretend GitHub and a bucket on the emulator.

import {
  dependencies as relayDependencies, handle as handleReport, loadConfig as loadRelayConfig,
} from "../../supabase-edge/supabase/functions/beacon-relay/relay.ts";
import {
  dependencies as privateDependencies, handle as handlePrivate, loadConfig as loadPrivateConfig,
  type Dependencies as PrivateDependencies,
} from "../../supabase-edge/supabase/functions/beacon-private/private.ts";
import { clientAddressOf, type Handler } from "./web.ts";

/** The one secret holds every setting as a JSON object, under the names the relay already uses. */
export function settingsFrom(secret: string): (name: string) => string | undefined {
  const values = JSON.parse(secret) as Record<string, unknown>;
  return (name) => {
    const value = values[name];
    if (value === undefined || value === null) return undefined;
    return typeof value === "string" ? value : JSON.stringify(value);
  };
}

export function relayHandler(secret: string, fetchFn: typeof fetch = fetch): Handler {
  const deps = { ...relayDependencies(loadRelayConfig(settingsFrom(secret)), fetchFn), clientAddressOf };
  return (request) => handleReport(request, deps);
}

export function privateHandler(secret: string, store: PrivateDependencies["store"]): Handler {
  const deps = { ...privateDependencies(loadPrivateConfig(settingsFrom(secret)), store), clientAddressOf };
  return (request) => handlePrivate(request, deps);
}
