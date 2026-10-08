import { type RelayConfig } from "./transport";
import { type AppIdentity, type FeedbackKind, type Reporter } from "./types";
export declare const CONSENT_VERSION = "2026-10-08.web.1";
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
    /** Set false to open the sheet only from your own control with `Beacon.open()`. */
    button?: boolean;
    onSent?: (reference: string) => void;
}
export declare class BeaconSheet {
    private opts;
    private host;
    private root;
    private dialog;
    private launch;
    private step;
    private answers;
    private shown;
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
    private reporter;
    private el;
    private render;
    private renderPick;
    private renderConsent;
    private field;
    private renderForm;
    private renderReview;
    private send;
    private renderSent;
}
export type { FeedbackKind };
