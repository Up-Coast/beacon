import { describe, expect, it } from "vitest";
import { canSubmit, checkCompleteness, isEmptyInSubstance } from "../src/completeness";
import { newReference, renderIssue } from "../src/render";
import { sweep } from "../src/redaction";
import { sendToRelay } from "../src/transport";
import type { Answers, WebContext } from "../src/types";

const ctx: WebContext = {
  page: "/portal/sessions",
  origin: "https://example.test",
  userAgent: "UA | pipe",
  language: "en-CA",
  timeZone: "America/Vancouver",
  viewport: "1200x800",
  screen: "1440x900 @2x",
  colorScheme: "light",
  online: true,
  hostNotes: [{ name: "Role", value: "member" }],
};

const bug: Answers = {
  kind: "bug",
  impact: "slowed",
  whatHappened: "The page went white and stayed white. Then nothing.",
  expected: "The class would open with the video",
  steps: ["Open the learning portal", "Press Continue on the class", ""],
  reproducibility: "every-time",
};

describe("completeness (ported from Beacon's apps)", () => {
  it("blocks placeholders and short answers", () => {
    expect(isEmptyInSubstance("idk")).toBe(true);
    expect(isEmptyInSubstance("It doesn't work.")).toBe(true);
    expect(canSubmit({ kind: "bug", impact: "noticed", whatHappened: "x", expected: "", steps: [] })).toBe(false);
  });
  it("lets a complete bug through and asks about reproducibility without blocking", () => {
    expect(canSubmit(bug)).toBe(true);
    const unknown = checkCompleteness({ ...bug, reproducibility: "unknown" });
    expect(unknown.some((i) => i.field === "reproducibility" && !i.blocking)).toBe(true);
    expect(canSubmit({ ...bug, reproducibility: "unknown" })).toBe(true);
  });
  it("needs both halves of a change request and a sentence of feedback", () => {
    expect(canSubmit({ kind: "change-request", impact: "noticed", whatToChange: "The header is too tall for me" })).toBe(false);
    expect(canSubmit({ kind: "feedback", impact: "noticed", message: "Thank you, this is really useful" })).toBe(true);
    expect(canSubmit({ kind: "feature-request", impact: "noticed", whatIWant: "Mark workbook steps as done" })).toBe(true);
  });
});

describe("issue rendering (same layout triage parses)", () => {
  const input = {
    answers: bug,
    reporter: { accountID: "web-abc" },
    anonymous: true,
    app: { id: "ca.upcoast.portal", name: "Up Coast", version: "1.0", build: "42" },
    context: ctx,
    reference: "BN-01ABFF",
    startedAt: new Date("2026-10-08T00:00:00Z"),
    consentVersion: "v1",
  };
  it("uses Beacon's headings, labels and metadata block", () => {
    const issue = renderIssue(input);
    expect(issue.labels).toEqual(["beacon", "type:bug", "impact:slowed"]);
    expect(issue.title).toBe("The page went white and stayed white");
    for (const h of ["## What they expected", "## What actually happened", "## Steps to see it", "## Does it happen again?", "## How much this affects them"]) {
      expect(issue.body).toContain(h);
    }
    expect(issue.body).toContain("1. Open the learning portal");
    expect(issue.body).toContain("2. Press Continue on the class");
    expect(issue.body).toContain('"platform": "web"');
    expect(issue.body).toContain('"reference": "BN-01ABFF"');
    expect(issue.body).toContain("Reported anonymously");
    expect(issue.body).not.toContain("UA | pipe");
  });
  it("masks credential-shaped text the reporter typed", () => {
    const issue = renderIssue({
      ...input,
      answers: { ...bug, whatHappened: "It said token ghp_abcdefghijklmnopqrstuvwxyz0123 in the box" },
    });
    expect(issue.body).not.toContain("ghp_abcdefghijklmnopqrstuvwxyz0123");
    expect(issue.body).toContain("[removed by Beacon]");
    expect(sweep("nothing secret here").findings).toEqual([]);
  });
  it("names the kind label for every kind", () => {
    const f = renderIssue({ ...input, answers: { kind: "feature-request", impact: "noticed", whatIWant: "Mark steps done" } });
    expect(f.labels[1]).toBe("type:feature-request");
    const c = renderIssue({ ...input, answers: { kind: "change-request", impact: "noticed", whatToChange: "a", instead: "b" } });
    expect(c.labels[1]).toBe("type:change-request");
  });
  it("makes a BN- reference the relay accepts", () => {
    expect(newReference(new Uint8Array([1, 171, 255]))).toBe("BN-01ABFF");
  });
});

describe("relay transport", () => {
  const payload = {
    title: "t", body: "b", labels: ["beacon"], reference: "BN-000000", account: "web-x", app: "ca.upcoast.portal", attachments: [],
  };
  it("posts JSON with the bearer token and reads the status", async () => {
    let seen: { url: string; init: RequestInit } | null = null;
    const ok = (async (url: string, init: RequestInit) => {
      seen = { url, init };
      return new Response("{}", { status: 201 });
    }) as unknown as typeof fetch;
    expect(await sendToRelay({ url: "https://r.test/f", token: "tok" }, payload, ok)).toEqual({ ok: true });
    expect(seen!.url).toBe("https://r.test/f");
    expect((seen!.init.headers as Record<string, string>).authorization).toBe("Bearer tok");
    const limited = (async () => new Response("{}", { status: 429 })) as unknown as typeof fetch;
    expect(await sendToRelay({ url: "x" }, payload, limited)).toEqual({ ok: false, reason: "too-many" });
    const down = (async () => {
      throw new Error("offline");
    }) as unknown as typeof fetch;
    expect(await sendToRelay({ url: "x" }, payload, down)).toEqual({ ok: false, reason: "unreachable" });
  });
});
