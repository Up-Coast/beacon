import { COMPLETENESS as C } from "./wording";
import type { Answers } from "./types";

/** The deterministic gate, ported from Sources/BeaconCore/Completeness.swift. A blocking issue means the report
 * cannot be filed: the reporter is the only person who knows the answer, and by the time anyone notices it is
 * missing they have moved on. Non-blocking issues are said out loud and never stop a send. */

export interface CompletenessIssue {
  field: string;
  message: string;
  blocking: boolean;
}

export const MINIMUM_MEANINGFUL_CHARACTERS = 12;

const PLACEHOLDERS = new Set([
  "n/a", "na", "none", "nothing", "idk", "i don't know", "i dont know", "test", "asdf", "asd", "qwerty",
  "x", "xx", "xxx", "-", "--", ".", "?", "??", "todo", "tbd", "see above", "same", "same as above",
  "it broke", "broke", "doesn't work", "does not work", "not working", "it doesn't work", "error", "bug", "help",
]);

const trimmed = (text: string | undefined) => (text ?? "").trim();

export function isEmptyInSubstance(text: string | undefined): boolean {
  const t = trimmed(text);
  if (!t) return true;
  const bare = t.toLowerCase().replace(/^[.!?,;:"' ]+|[.!?,;:"' ]+$/g, "");
  return PLACEHOLDERS.has(bare);
}

export function tooShort(text: string | undefined): boolean {
  return trimmed(text).length < MINIMUM_MEANINGFUL_CHARACTERS;
}

const block = (field: string, message: string): CompletenessIssue => ({ field, message, blocking: true });

export function cleanSteps(steps: string[] | undefined): string[] {
  return (steps ?? []).map((s) => s.trim()).filter(Boolean);
}

export function checkCompleteness(a: Answers): CompletenessIssue[] {
  const issues: CompletenessIssue[] = [];
  switch (a.kind) {
    case "bug": {
      if (isEmptyInSubstance(a.whatHappened)) issues.push(block("whatHappened", C.whatHappenedEmpty));
      else if (tooShort(a.whatHappened)) issues.push(block("whatHappened", C.whatHappenedShort));
      if (isEmptyInSubstance(a.expected)) issues.push(block("expected", C.expectedEmpty));
      else if (tooShort(a.expected)) issues.push(block("expected", C.expectedShort));
      const steps = cleanSteps(a.steps);
      if (steps.length === 0) issues.push(block("steps", C.stepsEmpty));
      else if (steps.length === 1 && tooShort(steps[0])) issues.push(block("steps", C.stepsOneShort));
      else if (steps.every((s) => isEmptyInSubstance(s))) issues.push(block("steps", C.stepsNoAction));
      if ((a.reproducibility ?? "unknown") === "unknown") {
        issues.push({ field: "reproducibility", message: C.reproducibilityUnknown, blocking: false });
      }
      break;
    }
    case "feature-request":
      if (isEmptyInSubstance(a.whatIWant) || tooShort(a.whatIWant)) issues.push(block("whatIWant", C.whatIWant));
      if (isEmptyInSubstance(a.why)) issues.push({ field: "why", message: C.why, blocking: false });
      break;
    case "change-request":
      if (isEmptyInSubstance(a.whatToChange) || tooShort(a.whatToChange)) {
        issues.push(block("whatToChange", C.whatToChange));
      }
      if (isEmptyInSubstance(a.instead) || tooShort(a.instead)) issues.push(block("instead", C.instead));
      break;
    case "feedback":
      if (isEmptyInSubstance(a.message) || tooShort(a.message)) issues.push(block("message", C.feedback));
      break;
  }
  return issues;
}

export const blockingIssues = (a: Answers) => checkCompleteness(a).filter((i) => i.blocking);
export const canSubmit = (a: Answers) => blockingIssues(a).length === 0;
