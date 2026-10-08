import type { FeedbackKind, Impact, Reproducibility } from "./types";
/** Every sentence a reporter reads. Same words as Beacon's apps (Sources/BeaconCore) wherever the thing is the same. */
export declare const KIND_WORDS: Record<FeedbackKind, {
    title: string;
    blurb: string;
}>;
export declare const IMPACT_WORDS: Record<Impact, string>;
export declare const REPRODUCIBILITY_WORDS: Record<Reproducibility, string>;
export declare const FIELD_LABELS: {
    readonly whatHappened: "What actually happened?";
    readonly expected: "What did you expect to happen?";
    readonly steps: "What did you do, step by step?";
    readonly reproducibility: "Does it happen again?";
    readonly whatIWant: "What do you want to be able to do?";
    readonly why: "What are you trying to do that is hard right now?";
    readonly idea: "Do you have an idea how it could work? (optional)";
    readonly whatToChange: "What would you like changed?";
    readonly instead: "What would you like instead?";
    readonly message: "What's on your mind?";
    readonly impact: "How much does this affect you?";
    readonly name: "Your name (optional)";
    readonly contact: "Your email, if you'd like us to be able to ask you about it (optional)";
};
export declare const COMPLETENESS: {
    readonly whatHappenedEmpty: "Say what actually happened. Even “the page went white and stayed white” is enough to start from.";
    readonly whatHappenedShort: "A few more words about what happened would help — what did you see on screen?";
    readonly expectedEmpty: "Say what you expected instead. This is the one that tells us whether it is broken or just confusing.";
    readonly expectedShort: "What did you think would happen? A short sentence is fine.";
    readonly stepsEmpty: "Add the steps you took. Start from where you were when you opened the page.";
    readonly stepsOneShort: "One short step isn't enough to follow. What did you do just before this, and what did you click?";
    readonly stepsNoAction: "The steps need to say what you did — each one an action.";
    readonly reproducibilityUnknown: "If you can, try it once more. A bug nobody can make happen again can't be worked on — so this one answer changes more than any other.";
    readonly whatIWant: "Say what you want to be able to do. Describe it as the thing you're trying to get done, not the button.";
    readonly why: "What are you trying to do that this makes hard right now? Knowing this often finds a better answer than the one you asked for.";
    readonly whatToChange: "Say what you'd like changed — the thing that works today but that you'd do differently.";
    readonly instead: "Say what you'd like instead. A sentence about how it should work is plenty.";
    readonly feedback: "Tell us what's on your mind — a sentence or two is plenty.";
};
export declare const UI: {
    readonly button: "Report a problem";
    readonly pickTitle: "What would you like to tell us?";
    readonly back: "Back";
    readonly next: "Next";
    readonly send: "Send";
    readonly sending: "Sending…";
    readonly close: "Close";
    readonly done: "Close";
    readonly consentHeadline: "Before you send this, here's what happens to it";
    readonly consentAccept: "I understand — let's go";
    readonly consentPoints: (org: string) => string[];
    readonly reviewTitle: "This is what will be sent";
    readonly sentTo: (org: string) => string;
    readonly referenceLabel: "Reference";
    readonly notReachable: (org: string) => string;
    readonly refused: "That didn't go through. Try again in a minute.";
    readonly tooMany: "That is a lot of reports in a short time. Try again later.";
};
