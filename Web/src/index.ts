import { BeaconSheet, type BeaconOptions } from "./ui";

export type { BeaconOptions } from "./ui";
export { checkCompleteness, canSubmit, blockingIssues, isEmptyInSubstance } from "./completeness";
export { renderIssue, newReference, derivedTitle } from "./render";
export { sweep } from "./redaction";
export { sendToRelay } from "./transport";
export { collectContext } from "./context";
export * from "./types";

let current: BeaconSheet | null = null;

/** Puts Beacon on the page: a Report a problem button and the sheet it opens. Safe to call again: the
 * previous one is removed first. */
export function mount(options: BeaconOptions): BeaconSheet {
  current?.destroy();
  current = new BeaconSheet(options);
  return current;
}

/** Opens the sheet from your own control. */
export function open(): void {
  current?.open();
}

/** Takes Beacon off the page. */
export function unmount(): void {
  current?.destroy();
  current = null;
}

export const Beacon = { mount, open, unmount };
