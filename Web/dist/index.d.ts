import { BeaconSheet, type BeaconOptions } from "./ui";
export type { BeaconOptions } from "./ui";
export { checkCompleteness, canSubmit, blockingIssues, isEmptyInSubstance } from "./completeness";
export { renderIssue, newReference, derivedTitle } from "./render";
export { sweep } from "./redaction";
export { sendToRelay } from "./transport";
export { collectContext } from "./context";
export * from "./types";
/** Puts Beacon on the page: a Report a problem button and the sheet it opens. Safe to call again: the
 * previous one is removed first. */
export declare function mount(options: BeaconOptions): BeaconSheet;
/** Opens the sheet from your own control. */
export declare function open(): void;
/** Takes Beacon off the page. */
export declare function unmount(): void;
export declare const Beacon: {
    mount: typeof mount;
    open: typeof open;
    unmount: typeof unmount;
};
