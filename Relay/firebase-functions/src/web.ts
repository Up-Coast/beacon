// Turns a Node request into the web `Request` the shared handlers take, and writes
// the web `Response` back. The functions framework has already read the body, so it
// is taken from `rawBody` when that is set, and streamed when it is not.

import type { IncomingMessage, ServerResponse } from "node:http";
import { Readable } from "node:stream";

export type NodeRequest = IncomingMessage & { rawBody?: Buffer };
export type Handler = (request: Request) => Promise<Response>;

const addresses = new WeakMap<Request, string>();

/** The hop the platform's proxy added, else the connection's own address. */
function callerOf(req: NodeRequest): string {
  const forwarded = [req.headers["x-forwarded-for"]].flat().join(",").split(",").map((hop) => hop.trim());
  return forwarded.at(-1) || req.socket.remoteAddress || "unknown";
}

/** The address the platform reported for a request made by `toWebRequest`. */
export function clientAddressOf(request: Request): string {
  return addresses.get(request) ?? "unknown";
}

export function toWebRequest(req: NodeRequest): Request {
  const headers = new Headers();
  for (const [name, value] of Object.entries(req.headers)) {
    if (value !== undefined) headers.set(name, [value].flat().join(", "));
  }
  const method = req.method ?? "GET";
  const hasBody = method !== "GET" && method !== "HEAD";
  const body = !hasBody ? undefined : req.rawBody ?? (Readable.toWeb(req) as unknown as ReadableStream<Uint8Array>);
  const request = new Request(`https://${req.headers.host ?? "localhost"}${req.url ?? "/"}`, {
    method, headers, body: body as BodyInit | undefined, duplex: "half",
  } as RequestInit);
  addresses.set(request, callerOf(req));
  return request;
}

export async function writeWebResponse(res: ServerResponse, response: Response): Promise<void> {
  res.statusCode = response.status;
  response.headers.forEach((value, name) => res.setHeader(name, value));
  res.end(Buffer.from(await response.arrayBuffer()));
}

/**
 * A function body that builds its handler on the first request, so a setting that is
 * missing answers 503 with `unavailable` instead of stopping the function from loading.
 */
export function serve(build: () => Handler, unavailable: unknown) {
  let handler: Handler | undefined;
  return async (req: NodeRequest, res: ServerResponse): Promise<void> => {
    try {
      handler ??= build();
    } catch (error) {
      console.error(`not set up: ${error instanceof Error ? error.message : String(error)}`);
      await writeWebResponse(
        res, new Response(JSON.stringify(unavailable), { status: 503, headers: { "Content-Type": "application/json" } }));
      return;
    }
    await writeWebResponse(res, await handler(toWebRequest(req)));
  };
}
