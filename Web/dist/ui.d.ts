import { type RelayConfig } from "./transport";
import { type AppIdentity, type FeedbackKind, type Reporter } from "./types";
export declare const CONSENT_VERSION = "2026-10-08.anonymous.2";
export interface BeaconOptions {
    app: AppIdentity;
    relay: RelayConfig;
    /** Who reports go to, as the reporter reads it ("the Up Coast team"). */
    organizationName?: string;
    /** A signed-in person, when the host knows one. Without it each browser gets a random anonymous id. */
    reporter?: Reporter;
    /** Extra facts the host wants on every report. */
    hostNotes?: () => {
        name: string;
        value: string;
    }[];
    /** Replaces the mark on the button: an SVG string. */
    icon?: string;
    /** Where the floating button sits. Default bottom-right. */
    position?: "bottom-right" | "bottom-left";
    /** How many pixels higher than its usual spot the floating button sits, to clear a bar along the bottom of the page. Default 0. */
    bottomOffset?: number;
    /** Set false to open the sheet only from your own control with `Beacon.open()`. */
    button?: boolean;
    onSent?: (reference: string) => void;
}
/** The floating button's distance from the bottom of the window: the usual 24px, raised by `bottomOffset`. */
export declare function launchBottom(bottomOffset?: number): number;
export declare class BeaconSheet {
    private opts;
    private host;
    private root;
    private dialog;
    private launch;
    private step;
    private answers;
    private identity;
    private files;
    private problem;
    private blocking;
    private advisory;
    private busy;
    private failure;
    private reference;
    private startedAt;
    constructor(opts: BeaconOptions);
    destroy(): void;
    open(): void;
    close(): void;
    private onClosed;
    private org;
    private saveIdentity;
    private reporter;
    private el;
    private button;
    private render;
    private title;
    private renderConsent;
    /** Who it is from, asked once and remembered on this browser; same words as the Mac and iPhone sheet. */
    private identityBlock;
    /** The first line the reporter reads: what tool this is and where to get it. */
    private introLine;
    private renderPick;
    private block;
    private text;
    private choice;
    private renderForm;
    private toReview;
    private attachments;
    private addFiles;
    private encode;
    private issue;
    private renderReview;
    private send;
    private renderSent;
}
export type { FeedbackKind };
