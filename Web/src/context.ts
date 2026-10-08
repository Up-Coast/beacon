import type { WebContext } from "./types";

/** What the browser tells us with no permission prompt. The page address loses its query string and hash, which
 * can hold tokens. Nothing from inside the page's content is read; there are no screenshots. */
export function collectContext(
  hostNotes: { name: string; value: string }[] = [],
  win: Window = window,
): WebContext {
  const nav = win.navigator;
  const loc = win.location;
  let timeZone = "unknown";
  try {
    timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || "unknown";
  } catch {
    /* keep unknown */
  }
  const dark = typeof win.matchMedia === "function" && win.matchMedia("(prefers-color-scheme: dark)").matches;
  return {
    page: loc.pathname || "/",
    origin: loc.origin,
    userAgent: (nav.userAgent || "unknown").slice(0, 300),
    language: nav.language || "unknown",
    timeZone,
    viewport: `${win.innerWidth}x${win.innerHeight}`,
    screen: `${win.screen?.width ?? 0}x${win.screen?.height ?? 0} @${win.devicePixelRatio || 1}x`,
    colorScheme: dark ? "dark" : "light",
    online: nav.onLine !== false,
    hostNotes,
  };
}
