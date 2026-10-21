// The Supabase Edge Function entry point. Everything it does is in private.ts.

import { ANSWERS, dependencies, type Dependencies, handle, loadConfig } from "./private.ts";

let deps: Dependencies | undefined;
try {
  deps = dependencies(loadConfig((name) => Deno.env.get(name)));
} catch (error) {
  console.error(`beacon-private is not set up: ${error instanceof Error ? error.message : String(error)}`);
}

Deno.serve((request) =>
  deps
    ? handle(request, deps)
    : new Response(JSON.stringify({ message: ANSWERS.unauthorized }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    })
);
