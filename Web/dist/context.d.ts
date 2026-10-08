import type { WebContext } from "./types";
/** What the browser tells us with no permission prompt. The page address loses its query string and hash, which
 * can hold tokens. Nothing from inside the page's content is read; there are no screenshots. */
export declare function collectContext(hostNotes?: {
    name: string;
    value: string;
}[], win?: Window): WebContext;
