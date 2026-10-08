/** The four things a person can file; the same four as Beacon's apps. */
export type FeedbackKind = "bug" | "feature-request" | "change-request" | "feedback";
export const KINDS: readonly FeedbackKind[] = ["bug", "feature-request", "change-request", "feedback"];

export type Impact = "blocked" | "slowed" | "irritating" | "noticed";
export const IMPACTS: readonly Impact[] = ["blocked", "slowed", "irritating", "noticed"];

export type Reproducibility = "every-time" | "sometimes" | "once" | "unknown";
export const REPRODUCIBILITIES: readonly Reproducibility[] = ["every-time", "sometimes", "once", "unknown"];

/** What a reporter wrote. Only the fields of the chosen kind are read. */
export interface Answers {
  kind: FeedbackKind;
  impact: Impact;
  title?: string;
  /** bug */
  whatHappened?: string;
  expected?: string;
  steps?: string[];
  reproducibility?: Reproducibility;
  /** feature-request */
  whatIWant?: string;
  why?: string;
  idea?: string;
  /** change-request */
  whatToChange?: string;
  instead?: string;
  /** feedback */
  message?: string;
  /** Optional ways to reach them. */
  name?: string;
  contact?: string;
}

/** Who filed it. A host with accounts supplies one; otherwise Beacon makes an anonymous one per browser. */
export interface Reporter {
  accountID: string;
  displayName?: string;
  contact?: string;
}

/** Which app, which build: never optional, so triage can tell a fixed bug from a live one. */
export interface AppIdentity {
  /** Routes the report to a repository in the relay's TARGETS, like an app's bundle identifier. */
  id: string;
  name: string;
  version?: string;
  build?: string;
  commit?: string;
}

/** What the browser tells us, collected with no permission prompt and nothing from inside the page's content. */
export interface WebContext {
  /** The address without query string or hash: those can hold tokens. */
  page: string;
  origin: string;
  userAgent: string;
  language: string;
  timeZone: string;
  viewport: string;
  screen: string;
  colorScheme: string;
  online: boolean;
  /** Anything the host adds for itself. */
  hostNotes: { name: string; value: string }[];
}

export interface Issue {
  title: string;
  body: string;
  labels: string[];
}

export interface Payload extends Issue {
  reference: string;
  account: string;
  app: string;
  contact?: string;
  attachments: { filename: string; base64: string }[];
}
