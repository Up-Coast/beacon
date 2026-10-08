import { cleanSteps } from "./completeness";
import { sweep } from "./redaction";
import { IMPACT_WORDS, REPRODUCIBILITY_WORDS } from "./wording";
import type { Answers, AppIdentity, Issue, Reporter, WebContext } from "./types";

/** Turns a report into the GitHub issue triage works from. Ported from IssueRenderer in
 * Sources/BeaconCore/IssueRendering.swift: the headings are fixed and machine-readable, the reporter's words are
 * quoted and never summarised, and the trailing metadata block is the part triage parses. */

const quote = (text: string | undefined): string => {
  const t = (text ?? "").trim();
  if (!t) return "> _(not said)_";
  return t
    .split("\n")
    .map((l) => "> " + l)
    .join("\n");
};

function truncate(text: string, limit: number): string {
  if (text.length <= limit) return text;
  let cut = text.slice(0, limit);
  const space = cut.lastIndexOf(" ");
  if (space > 0) cut = cut.slice(0, space);
  return cut + "…";
}

export function derivedTitle(a: Answers): string {
  const source =
    a.kind === "bug"
      ? a.whatHappened
      : a.kind === "feature-request"
        ? a.whatIWant
        : a.kind === "change-request"
          ? a.whatToChange
          : a.message;
  const firstLine = (source ?? "").split(/\r?\n/).find((l) => l.trim()) ?? "";
  const sentence = firstLine.split(".")[0] ?? firstLine;
  return truncate(sentence.trim(), 72);
}

export function newReference(random: Uint8Array): string {
  return (
    "BN-" +
    Array.from(random.slice(0, 3), (b) => b.toString(16).padStart(2, "0"))
      .join("")
      .toUpperCase()
  );
}

export function reporterLine(reporter: Reporter, anonymous: boolean): string {
  const reach = reporter.contact?.trim().replace(/\n/g, " ");
  if (anonymous && reporter.displayName) {
    return `Reported by **${reporter.displayName}** (\`${reporter.accountID}\`) — they chose to give their name without an account.${reach ? ` Reach them at **${reach}**.` : ""}`;
  }
  if (anonymous) {
    return `Reported anonymously (\`${reporter.accountID}\`) — ${reach ? `they can be reached at **${reach}**.` : "they left no way to reach them."}`;
  }
  return `Reported by **${reporter.displayName ?? reporter.accountID}** (\`${reporter.accountID}\`) — they agreed to be contacted about this.${reach ? ` Reach them at **${reach}**.` : ""}`;
}

const esc = (v: string) => v.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n");

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

export function renderIssue(input: RenderInput): Issue {
  const { answers: a, app, context } = input;
  // Anything credential-shaped the reporter typed is masked before it leaves the browser.
  const s = (t: string | undefined) => sweep(t ?? "").text;
  const out: string[] = [`> Filed from inside the website with Beacon. ${reporterLine(input.reporter, input.anonymous)}`, ""];

  if (a.kind === "bug") {
    out.push("## What they expected", "", quote(s(a.expected)), "");
    out.push("## What actually happened", "", quote(s(a.whatHappened)), "");
    out.push("## Steps to see it", "");
    cleanSteps(a.steps).forEach((step, i) => out.push(`${i + 1}. ${s(step)}`));
    out.push("");
    out.push("## Does it happen again?", "", `**${REPRODUCIBILITY_WORDS[a.reproducibility ?? "unknown"]}**`, "");
  } else if (a.kind === "feature-request") {
    out.push("## What they want to be able to do", "", quote(s(a.whatIWant)), "");
    if ((a.why ?? "").trim()) out.push("## Why — the problem behind the request", "", quote(s(a.why)), "");
    if ((a.idea ?? "").trim()) out.push("## Their idea", "", quote(s(a.idea)), "");
  } else if (a.kind === "change-request") {
    out.push("## What they would like changed", "", quote(s(a.whatToChange)), "");
    out.push("## What they would like instead", "", quote(s(a.instead)), "");
    if ((a.why ?? "").trim()) out.push("## Why it matters to them", "", quote(s(a.why)), "");
  } else {
    out.push("## What they said", "", quote(s(a.message)), "");
  }

  out.push("## How much this affects them", "", `**${IMPACT_WORDS[a.impact]}**`, "");

  out.push("<details>", "<summary>Page, browser and settings</summary>", "", "| | |", "|---|---|");
  out.push(`| App | ${app.name}${app.version ? ` ${app.version}` : ""}${app.build ? ` (${app.build})` : ""} |`);
  if (app.commit) out.push(`| Built from | \`${app.commit}\` |`);
  out.push(`| Page | \`${context.origin}${context.page}\` |`);
  out.push(`| Browser | ${context.userAgent.replace(/\|/g, "/")} |`);
  out.push(`| Window | ${context.viewport} (screen ${context.screen}) |`);
  out.push(`| Language | ${context.language}, ${context.timeZone} |`);
  out.push(`| Appearance | ${context.colorScheme} |`);
  out.push(`| Online | ${context.online ? "yes" : "no"} |`, "");
  if (context.hostNotes.length) {
    out.push("**From the site**", "");
    for (const n of context.hostNotes) out.push(`- **${n.name}**: ${n.value}`);
    out.push("");
  }
  out.push("</details>", "");

  const meta: Record<string, string> = {
    beacon_schema: "1",
    platform: "web",
    report_id: input.reference,
    reference: input.reference,
    kind: a.kind,
    impact: a.impact,
    area: "",
    account: input.reporter.accountID,
    app_version: app.version ?? "",
    app_build: app.build ?? "",
    consent_version: input.consentVersion,
    started_at: input.startedAt.toISOString(),
  };
  if (app.commit) meta.commit = app.commit;
  if (a.kind === "bug") {
    meta.reproducibility = a.reproducibility ?? "unknown";
    meta.step_count = String(cleanSteps(a.steps).length);
  }
  const json = Object.keys(meta)
    .sort()
    .map((k) => `  "${k}": "${esc(meta[k]!)}"`)
    .join(",\n");
  out.push(`<!-- beacon-metadata\n{\n${json}\n}\n-->`);

  const written = (a.title ?? "").trim();
  return {
    title: written || derivedTitle(a) || "Report from the website",
    body: out.join("\n"),
    labels: ["beacon", `type:${a.kind}`, `impact:${a.impact}`],
  };
}
