import type { Answers, AppIdentity, Issue, Reporter, WebContext } from "./types";
export declare function derivedTitle(a: Answers): string;
export declare function newReference(random: Uint8Array): string;
export declare function reporterLine(reporter: Reporter, anonymous: boolean): string;
export interface RenderInput {
    answers: Answers;
    reporter: Reporter;
    anonymous: boolean;
    app: AppIdentity;
    context: WebContext;
    reference: string;
    startedAt: Date;
    consentVersion: string;
}
export declare function renderIssue(input: RenderInput): Issue;
