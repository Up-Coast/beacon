import type { Answers } from "./types";
/** The deterministic gate, ported from Sources/BeaconCore/Completeness.swift. A blocking issue means the report
 * cannot be filed: the reporter is the only person who knows the answer, and by the time anyone notices it is
 * missing they have moved on. Non-blocking issues are said out loud and never stop a send. */
export interface CompletenessIssue {
    field: string;
    message: string;
    blocking: boolean;
}
export declare const MINIMUM_MEANINGFUL_CHARACTERS = 12;
export declare function isEmptyInSubstance(text: string | undefined): boolean;
export declare function tooShort(text: string | undefined): boolean;
export declare function cleanSteps(steps: string[] | undefined): string[];
/** `attachmentCount` is how many files the reporter has added; only the feedback-document kind needs one. */
export declare function checkCompleteness(a: Answers, attachmentCount?: number): CompletenessIssue[];
export declare const blockingIssues: (a: Answers, attachmentCount?: number) => CompletenessIssue[];
export declare const canSubmit: (a: Answers, attachmentCount?: number) => boolean;
