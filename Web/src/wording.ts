import type { FeedbackKind, Impact, Reproducibility } from "./types";

/** Every sentence a reporter reads. Same words as Beacon's apps (Sources/BeaconCore) wherever the thing is the same. */

export const KIND_WORDS: Record<FeedbackKind, { title: string; blurb: string }> = {
  bug: { title: "Something's broken", blurb: "The page did something you didn't expect, or stopped working." },
  "feature-request": {
    title: "Something's missing",
    blurb: "You want it to do something it doesn't do yet, or you have an idea.",
  },
  "change-request": { title: "Change request", blurb: "You'd like something to work or look differently." },
  feedback: { title: "Something else", blurb: "Anything else you want to tell us." },
};

export const IMPACT_WORDS: Record<Impact, string> = {
  blocked: "I can't do what I came to do",
  slowed: "I found a way around it, but it costs me time",
  irritating: "It bothers me, but I can keep working",
  noticed: "I noticed it — it doesn't really affect me",
};

export const REPRODUCIBILITY_WORDS: Record<Reproducibility, string> = {
  "every-time": "Every time I follow those steps",
  sometimes: "Sometimes — it doesn't always happen",
  once: "It happened once and I haven't seen it since",
  unknown: "I haven't tried to make it happen again",
};

export const FIELD_LABELS = {
  whatHappened: "What actually happened?",
  expected: "What did you expect to happen?",
  steps: "What did you do, step by step?",
  reproducibility: "Does it happen again?",
  whatIWant: "What do you want to be able to do?",
  why: "What are you trying to do that is hard right now?",
  idea: "Do you have an idea how it could work? (optional)",
  whatToChange: "What would you like changed?",
  instead: "What would you like instead?",
  message: "What's on your mind?",
  impact: "How much does this affect you?",
  name: "Your name (optional)",
  contact: "Your email, if you'd like us to be able to ask you about it (optional)",
} as const;

export const COMPLETENESS = {
  whatHappenedEmpty:
    "Say what actually happened. Even “the page went white and stayed white” is enough to start from.",
  whatHappenedShort: "A few more words about what happened would help — what did you see on screen?",
  expectedEmpty:
    "Say what you expected instead. This is the one that tells us whether it is broken or just confusing.",
  expectedShort: "What did you think would happen? A short sentence is fine.",
  stepsEmpty: "Add the steps you took. Start from where you were when you opened the page.",
  stepsOneShort: "One short step isn't enough to follow. What did you do just before this, and what did you click?",
  stepsNoAction: "The steps need to say what you did — each one an action.",
  reproducibilityUnknown:
    "If you can, try it once more. A bug nobody can make happen again can't be worked on — so this one answer changes more than any other.",
  whatIWant:
    "Say what you want to be able to do. Describe it as the thing you're trying to get done, not the button.",
  why: "What are you trying to do that this makes hard right now? Knowing this often finds a better answer than the one you asked for.",
  whatToChange: "Say what you'd like changed — the thing that works today but that you'd do differently.",
  instead: "Say what you'd like instead. A sentence about how it should work is plenty.",
  feedback: "Tell us what's on your mind — a sentence or two is plenty.",
} as const;

export const UI = {
  button: "Report a problem",
  pickTitle: "What would you like to tell us?",
  back: "Back",
  next: "Next",
  send: "Send",
  sending: "Sending…",
  close: "Close",
  done: "Close",
  consentHeadline: "Before you send this, here's what happens to it",
  consentAccept: "I understand — let's go",
  consentPoints: (org: string) => [
    "You don't need an account. Your report carries a random number made for this site on this browser, so we can tell your reports apart.",
    "If you'd like us to be able to ask you about it, you can add your name and email. They go in your report. You can leave them out.",
    `Your report goes to ${org}, and only they can read it.`,
    "We collect the page you were on (without anything after a ? or #), your browser and screen size, your language and time zone. You can read all of it on the last screen before you send.",
    "Nothing from inside the page is read. We don't take screenshots or recordings.",
  ],
  reviewTitle: "This is what will be sent",
  sentTo: (org: string) => `Sent to ${org}. Thank you. If you get in touch about it, quote the reference below.`,
  referenceLabel: "Reference",
  notReachable: (org: string) => `${org} couldn't be reached. Nothing was lost; try again in a minute.`,
  refused: "That didn't go through. Try again in a minute.",
  tooMany: "That is a lot of reports in a short time. Try again later.",
} as const;
