// The Supabase Edge Function entry point. Everything it does is in relay.ts.

import { ANSWERS, dependencies, type Dependencies, handle, loadConfig } from "./relay.ts";

let deps: Dependencies | undefined;
let problem: string | undefined;
try {
  deps = dependencies(loadConfig((name) => Deno.env.get(name)));
} catch (error) {
  problem = error instanceof Error ? error.message : String(error);
  console.error(`beacon-relay is not set up: ${problem}`);
}

Deno.serve((request) =>
  deps
    ? handle(request, deps)
    : new Response(JSON.stringify({ error: ANSWERS.unauthorized }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    })
);
