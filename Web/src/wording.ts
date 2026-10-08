import type { FeedbackKind, Impact, Reproducibility } from "./types";

/** Every sentence a reporter reads. Same words as Beacon's apps (Sources/BeaconCore) wherever the thing is the same. */

export const KIND_WORDS: Record<FeedbackKind, { title: string; blurb: string }> = {
  bug: { title: "Something's broken", blurb: "The page did something you didn't expect, or stopped working." },
  "feature-request": {
    title: "Something's missing",
    blurb: "You want it to do something it doesn't do yet \u2014 or you have an idea.",
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
  expected: "What did you expect to happen?",
  whatHappened: "What actually happened?",
  steps: "What did you do to get there?",
  reproducibility: "Does it happen again?",
  whatIWant: "What do you want to be able to do?",
  why: "What makes that hard today?",
  idea: "Your idea (optional)",
  whatToChange: "What would you like changed?",
  instead: "What would you like instead?",
  changeWhy: "Why does it matter to you? (optional)",
  message: "What's on your mind?",
  impact: "How much is this affecting you?",
} as const;

/** The sentence under a label, where the Mac and iPhone sheet has one. */
export const FIELD_HINTS = {
  expected: "This is the one that tells us whether the page is broken or just confusing. Both are worth fixing.",
  whatHappened: "Say what you saw on screen.",
  steps: "One action per line, starting from where you were.",
  whatIWant: "Describe the thing you're trying to get done, rather than the button you think it needs.",
  why: "Knowing this often turns up a better answer than the one you asked for.",
  idea: "If you have a thought about how it could work, tell us. You can leave this empty.",
  whatToChange: "Say what works today that you'd like done differently.",
  impact: "This is what decides the order things get looked at, so an honest answer helps more than a dramatic one.",
  contact: "An email or a phone number, if you'd like us to be able to ask you about this. Leave it empty and your report is sent without one.",
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
  intro: (org: string) => {
    const owner = org.trim() ? `${org.trim()}\u2019s free tool` : "the free tool";
    return `We use ${owner} `;
  },
  introLink: "Beacon",
  introTail: " for user feedback and bug reports.",
  beaconHome: "https://github.com/Up-Coast/beacon",
  back: "Back",
  next: "Next",
  cancel: "Cancel",
  send: "Send",
  sending: "Sending\u2026",
  close: "Close",
  done: "Done",
  consentHeadline: "Before you send this, here's what happens to it",
  consentSubtitle: "You'll only see this once, unless it changes.",
  consentAccept: "I understand \u2014 let's go",
  consentPoints: (org: string) => [
    "You don't need an account. Your report carries a random number made for this site on this browser, so we can tell your reports apart.",
    "If you'd like us to be able to ask you about it, you can add your name and email. They go in your report, and we remember them on this browser so you only type them once. You can change or clear them any time, or send without them.",
    `Your report goes to ${org}, and only they can read it.`,
    "We collect the page you were on (without anything after a ? or #), your browser and window size, your language and time zone. You can read all of it on the next screen before you send.",
    "Anything you attach yourself \u2014 a screenshot, a file \u2014 we do read. That's the point of attaching it, and it's entirely your choice what to add.",
  ],
  identityLabel: "Your name and email, so we can follow up. We remember them on this browser.",
  nameLabel: "Name",
  emailLabel: "Email",
  withoutName: "Send without my name",
  withoutNameNote: "Your report will go without your name or email. You can add them any time.",
  addName: "Add my name",
  forget: "Forget them",
  blockingTitle: "Before this can go",
  attachTitle: "Anything to show us?",
  attachHint:
    "A picture of what you're looking at is usually worth more than another paragraph. Text, images and PDFs all work.",
  addFile: "Add a file",
  dropHere: "Drop files here",
  remove: "Remove",
  reviewTitle: "Here's what we'll send",
  reviewSubtitle: "Read it over. Nothing has left your browser yet.",
  goingTo: "Going to",
  from: "From",
  everything: "Everything being sent",
  sentTitle: "Sent \u2014 thank you",
  sentTo: (org: string) => `Sent to ${org}. Thank you. If you get in touch about it, quote the reference below.`,
  referenceLabel: "Your reference",
  notReachable: (org: string) => `${org.charAt(0).toUpperCase()}${org.slice(1)} couldn't be reached. Nothing was lost; try again in a minute.`,
  refused: "The report couldn't be delivered just now.",
  tooMany: "A lot of reports have come from here just now. Please try again in a little while.",
  tooLarge: "The report is too large to send. Removing the largest attachment usually does it.",
  anonymousFrom: "You, without your name",
} as const;

/** Files a reporter may add: the formats the triaging agent can read (Sources/BeaconCore/Attachment.swift). */
export const ACCEPTED_EXTENSIONS = new Set([
  "txt","md","markdown","log","json","yaml","yml","toml","csv","tsv","xml","html","htm","plist","diff","patch","rtf",
  "swift","js","ts","tsx","jsx","py","rb","go","rs","java","kt","c","h","cpp","hpp","m","mm","sh","sql","conf","ini",
  "png","jpg","jpeg","heic","heif","gif","webp","tiff","bmp","pdf","mov","mp4","m4v",
]);
export const MAX_FILE_BYTES = 25 * 1024 * 1024;
export const MAX_TOTAL_BYTES = 60 * 1024 * 1024;
/** What the relay takes in base64 (Relay/supabase-edge README). */
export const MAX_SEND_BASE64 = 30 * 1024 * 1024;

export function refusalFor(filename: string): string {
  const ext = filename.includes(".") ? filename.split(".").pop()!.toLowerCase() : "";
  const named = ext ? `A .${ext} file` : "That file";
  return `${named} can't be read by the person or the assistant who will look at this report, so adding it wouldn't help. Text, images and PDFs all work \u2014 a screenshot of what you're looking at is usually the most useful thing you can add.`;
}
