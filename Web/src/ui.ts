import { blockingIssues, checkCompleteness, type CompletenessIssue } from "./completeness";
import { BEACON_ICON_SVG } from "./icon";
import { collectContext } from "./context";
import { newReference, renderIssue } from "./render";
import { sendToRelay, type RelayConfig } from "./transport";
import { FIELD_LABELS as F, IMPACT_WORDS, KIND_WORDS, REPRODUCIBILITY_WORDS, UI } from "./wording";
import {
  IMPACTS,
  KINDS,
  REPRODUCIBILITIES,
  type Answers,
  type AppIdentity,
  type FeedbackKind,
  type Payload,
  type Reporter,
} from "./types";

export const CONSENT_VERSION = "2026-10-08.web.1";

export interface BeaconOptions {
  app: AppIdentity;
  relay: RelayConfig;
  /** Who reports go to, as the reporter reads it ("the Up Coast team"). */
  organizationName?: string;
  /** A signed-in person, when the host knows one. Without it each browser gets a random anonymous id. */
  reporter?: Reporter;
  /** Extra facts the host wants on every report. */
  hostNotes?: () => { name: string; value: string }[];
  /** Replaces the mark on the button: an SVG string. */
  icon?: string;
  /** Where the floating button sits. Default bottom-right. */
  position?: "bottom-right" | "bottom-left";
  /** Set false to open the sheet only from your own control with `Beacon.open()`. */
  button?: boolean;
  onSent?: (reference: string) => void;
}

const STORE = "beacon.web.";
function store(): Storage | null {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}
function get(key: string): string | null {
  try {
    return store()?.getItem(STORE + key) ?? null;
  } catch {
    return null;
  }
}
function set(key: string, value: string) {
  try {
    store()?.setItem(STORE + key, value);
  } catch {
    /* private mode: the sheet still works, it just asks again */
  }
}

function anonymousId(): string {
  let id = get("device");
  if (!id) {
    const bytes = new Uint8Array(8);
    crypto.getRandomValues(bytes);
    id = "web-" + Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
    set("device", id);
  }
  return id;
}

const CSS = `
:host{all:initial;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;color:#1f2937}
*{box-sizing:border-box}
.launch{position:fixed;bottom:16px;z-index:2147483000;display:inline-flex;align-items:center;gap:8px;border:1px solid #d1d5db;background:#fff;color:#111827;border-radius:999px;padding:8px 14px 8px 10px;font:600 14px system-ui;cursor:pointer;box-shadow:0 2px 10px rgba(0,0,0,.18)}
.launch.right{right:16px}.launch.left{left:16px}
.launch:hover{background:#f3f4f6}
.launch:focus-visible,button:focus-visible,input:focus-visible,textarea:focus-visible,select:focus-visible{outline:2px solid #2563eb;outline-offset:2px}
dialog{border:0;border-radius:14px;padding:0;width:min(560px,calc(100vw - 24px));max-height:calc(100vh - 24px);box-shadow:0 20px 60px rgba(0,0,0,.35);color:#1f2937;background:#fff}
dialog::backdrop{background:rgba(17,24,39,.55)}
.sheet{padding:22px 22px 18px;overflow:auto;max-height:calc(100vh - 24px)}
h2{font:700 19px system-ui;margin:0 0 6px}p{margin:0 0 12px;line-height:1.45;font-size:14px}
.kinds{display:grid;gap:10px;margin-top:12px}
.kind{text-align:left;border:1px solid #d1d5db;background:#fff;border-radius:10px;padding:12px 14px;cursor:pointer;font:inherit}
.kind:hover{border-color:#2563eb;background:#eff6ff}.kind b{display:block;font-size:15px}.kind span{font-size:13px;color:#4b5563}
label{display:block;font:600 13px system-ui;margin:14px 0 5px}
textarea,input,select{width:100%;font:14px system-ui;padding:9px 10px;border:1px solid #9ca3af;border-radius:8px;background:#fff;color:#111827}
textarea{min-height:84px;resize:vertical}
.err{color:#b91c1c;font-size:13px;margin:5px 0 0}.ask{color:#92400e;font-size:13px;margin:5px 0 0}
.row{display:flex;gap:10px;justify-content:flex-end;margin-top:18px;align-items:center}
.primary{background:#2563eb;color:#fff;border:0;border-radius:8px;padding:10px 18px;font:600 14px system-ui;cursor:pointer}
.primary:disabled{background:#9ca3af;cursor:not-allowed}.ghost{background:transparent;border:0;color:#2563eb;font:600 14px system-ui;cursor:pointer;padding:10px}
ul{margin:0 0 12px;padding-left:20px;font-size:14px;line-height:1.5}
table{border-collapse:collapse;font-size:13px;width:100%}td{padding:4px 6px;border-bottom:1px solid #e5e7eb;vertical-align:top;word-break:break-word}td:first-child{color:#6b7280;white-space:nowrap}
.ref{font:700 22px ui-monospace,Menlo,monospace;letter-spacing:.05em;margin:6px 0 14px}
.close{float:right;background:transparent;border:0;font-size:22px;line-height:1;cursor:pointer;color:#6b7280}
`;

type Step = "pick" | "consent" | "form" | "review" | "sent";

export class BeaconSheet {
  private host: HTMLElement;
  private root: ShadowRoot;
  private dialog: HTMLDialogElement;
  private launch: HTMLButtonElement | null = null;
  private step: Step = "pick";
  private answers: Answers = { kind: "bug", impact: "irritating", steps: [""] };
  private shown: Record<string, string> = {};
  private busy = false;
  private failure = "";
  private reference = "";
  private startedAt = new Date();

  constructor(private opts: BeaconOptions) {
    this.host = document.createElement("div");
    this.host.setAttribute("data-beacon", "");
    this.root = this.host.attachShadow({ mode: "open" });
    const style = document.createElement("style");
    style.textContent = CSS;
    this.dialog = document.createElement("dialog");
    this.dialog.addEventListener("close", () => this.onClosed());
    this.root.append(style, this.dialog);
    if (opts.button !== false) {
      const b = document.createElement("button");
      b.type = "button";
      b.className = `launch ${opts.position === "bottom-left" ? "left" : "right"}`;
      b.innerHTML = `${opts.icon ?? BEACON_ICON_SVG}<span>${UI.button}</span>`;
      b.addEventListener("click", () => this.open());
      this.launch = b;
      this.root.append(b);
    }
    document.body.append(this.host);
  }

  destroy() {
    this.host.remove();
  }

  open() {
    this.startedAt = new Date();
    this.step = "pick";
    this.failure = "";
    this.shown = {};
    this.answers = { kind: "bug", impact: "irritating", steps: [""] };
    this.render();
    if (!this.dialog.open) this.dialog.showModal();
  }

  close() {
    if (this.dialog.open) this.dialog.close();
  }

  private onClosed() {
    this.step = "pick";
  }

  private org(): string {
    return this.opts.organizationName ?? "the team";
  }

  private reporter(): { reporter: Reporter; anonymous: boolean } {
    const given = this.opts.reporter;
    if (given) {
      return {
        reporter: { ...given, contact: this.answers.contact?.trim() || given.contact },
        anonymous: false,
      };
    }
    return {
      reporter: {
        accountID: anonymousId(),
        displayName: this.answers.name?.trim() || undefined,
        contact: this.answers.contact?.trim() || undefined,
      },
      anonymous: true,
    };
  }

  private el<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Record<string, string> = {}, text?: string) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
    if (text !== undefined) e.textContent = text;
    return e;
  }

  private render() {
    const sheet = this.el("div", { class: "sheet" });
    const x = this.el("button", { class: "close", type: "button", "aria-label": UI.close }, "×");
    x.addEventListener("click", () => this.close());
    sheet.append(x);
    if (this.step === "pick") this.renderPick(sheet);
    else if (this.step === "consent") this.renderConsent(sheet);
    else if (this.step === "form") this.renderForm(sheet);
    else if (this.step === "review") this.renderReview(sheet);
    else this.renderSent(sheet);
    this.dialog.replaceChildren(sheet);
  }

  private renderPick(sheet: HTMLElement) {
    sheet.append(this.el("h2", {}, UI.pickTitle));
    sheet.append(this.el("p", {}, `This goes straight to ${this.org()}. You do not need an account.`));
    const list = this.el("div", { class: "kinds" });
    for (const kind of KINDS) {
      const b = this.el("button", { class: "kind", type: "button" });
      b.append(this.el("b", {}, KIND_WORDS[kind].title), this.el("span", {}, KIND_WORDS[kind].blurb));
      b.addEventListener("click", () => {
        this.answers = { ...this.answers, kind, steps: this.answers.steps ?? [""] };
        this.step = get("consent") === CONSENT_VERSION ? "form" : "consent";
        this.render();
      });
      list.append(b);
    }
    sheet.append(list);
  }

  private renderConsent(sheet: HTMLElement) {
    sheet.append(this.el("h2", {}, UI.consentHeadline));
    const ul = this.el("ul");
    for (const point of UI.consentPoints(this.org())) ul.append(this.el("li", {}, point));
    sheet.append(ul);
    const row = this.el("div", { class: "row" });
    const back = this.el("button", { class: "ghost", type: "button" }, UI.back);
    back.addEventListener("click", () => {
      this.step = "pick";
      this.render();
    });
    const ok = this.el("button", { class: "primary", type: "button" }, UI.consentAccept);
    ok.addEventListener("click", () => {
      set("consent", CONSENT_VERSION);
      this.step = "form";
      this.render();
    });
    row.append(back, ok);
    sheet.append(row);
  }

  private field(
    sheet: HTMLElement,
    key: keyof Answers & string,
    label: string,
    kind: "text" | "long" = "long",
    issue?: CompletenessIssue,
  ) {
    const id = `beacon-${key}`;
    sheet.append(this.el("label", { for: id }, label));
    const input = kind === "long" ? this.el("textarea", { id }) : this.el("input", { id, type: "text" });
    (input as HTMLTextAreaElement).value = ((this.answers[key] as string | undefined) ?? "") as string;
    input.addEventListener("input", () => {
      (this.answers as unknown as Record<string, unknown>)[key] = (input as HTMLTextAreaElement).value;
    });
    sheet.append(input);
    if (issue) sheet.append(this.el("p", { class: issue.blocking ? "err" : "ask", role: "alert" }, issue.message));
  }

  private renderForm(sheet: HTMLElement) {
    const a = this.answers;
    sheet.append(this.el("h2", {}, KIND_WORDS[a.kind].title));
    const issues = Object.keys(this.shown).length ? checkCompleteness(a) : [];
    const at = (field: string) => issues.find((i) => i.field === field);
    if (a.kind === "bug") {
      this.field(sheet, "whatHappened", F.whatHappened, "long", at("whatHappened"));
      this.field(sheet, "expected", F.expected, "long", at("expected"));
      sheet.append(this.el("label", { for: "beacon-steps" }, F.steps));
      const steps = this.el("textarea", { id: "beacon-steps", placeholder: "One step per line" });
      steps.value = (a.steps ?? []).join("\n");
      steps.addEventListener("input", () => (a.steps = steps.value.split("\n")));
      sheet.append(steps);
      const s = at("steps");
      if (s) sheet.append(this.el("p", { class: "err", role: "alert" }, s.message));
      sheet.append(this.el("label", { for: "beacon-repro" }, F.reproducibility));
      const repro = this.el("select", { id: "beacon-repro" });
      for (const r of REPRODUCIBILITIES) {
        const o = this.el("option", { value: r }, REPRODUCIBILITY_WORDS[r]);
        if ((a.reproducibility ?? "unknown") === r) o.selected = true;
        repro.append(o);
      }
      repro.addEventListener("change", () => (a.reproducibility = repro.value as never));
      sheet.append(repro);
      const r = at("reproducibility");
      if (r) sheet.append(this.el("p", { class: "ask" }, r.message));
    } else if (a.kind === "feature-request") {
      this.field(sheet, "whatIWant", F.whatIWant, "long", at("whatIWant"));
      this.field(sheet, "why", F.why, "long", at("why"));
      this.field(sheet, "idea", F.idea);
    } else if (a.kind === "change-request") {
      this.field(sheet, "whatToChange", F.whatToChange, "long", at("whatToChange"));
      this.field(sheet, "instead", F.instead, "long", at("instead"));
      this.field(sheet, "why", F.why);
    } else {
      this.field(sheet, "message", F.message, "long", at("message"));
    }
    sheet.append(this.el("label", { for: "beacon-impact" }, F.impact));
    const impact = this.el("select", { id: "beacon-impact" });
    for (const i of IMPACTS) {
      const o = this.el("option", { value: i }, IMPACT_WORDS[i]);
      if (a.impact === i) o.selected = true;
      impact.append(o);
    }
    impact.addEventListener("change", () => (a.impact = impact.value as never));
    sheet.append(impact);
    if (!this.opts.reporter) {
      this.field(sheet, "name", F.name, "text");
      this.field(sheet, "contact", F.contact, "text");
    }
    const row = this.el("div", { class: "row" });
    const back = this.el("button", { class: "ghost", type: "button" }, UI.back);
    back.addEventListener("click", () => {
      this.step = "pick";
      this.render();
    });
    const next = this.el("button", { class: "primary", type: "button" }, UI.next);
    next.addEventListener("click", () => {
      this.shown = { checked: "1" };
      if (blockingIssues(this.answers).length) {
        this.render();
        return;
      }
      this.step = "review";
      this.render();
    });
    row.append(back, next);
    sheet.append(row);
  }

  private renderReview(sheet: HTMLElement) {
    sheet.append(this.el("h2", {}, UI.reviewTitle));
    const ctx = collectContext(this.opts.hostNotes?.());
    const table = this.el("table");
    const rows: [string, string][] = [
      ["Page", ctx.page],
      ["Browser", ctx.userAgent],
      ["Window", `${ctx.viewport} (screen ${ctx.screen})`],
      ["Language", `${ctx.language}, ${ctx.timeZone}`],
      ...ctx.hostNotes.map((n) => [n.name, n.value] as [string, string]),
    ];
    for (const [k, v] of rows) {
      const tr = this.el("tr");
      tr.append(this.el("td", {}, k), this.el("td", {}, v));
      table.append(tr);
    }
    sheet.append(this.el("p", {}, "Along with what you wrote, this is everything that will be sent:"), table);
    if (this.failure) sheet.append(this.el("p", { class: "err", role: "alert" }, this.failure));
    const row = this.el("div", { class: "row" });
    const back = this.el("button", { class: "ghost", type: "button" }, UI.back);
    back.addEventListener("click", () => {
      this.step = "form";
      this.render();
    });
    const send = this.el("button", { class: "primary", type: "button" }, this.busy ? UI.sending : UI.send);
    send.disabled = this.busy;
    send.addEventListener("click", () => void this.send(ctx));
    row.append(back, send);
    sheet.append(row);
  }

  private async send(ctx: ReturnType<typeof collectContext>) {
    this.busy = true;
    this.failure = "";
    this.render();
    const bytes = new Uint8Array(3);
    crypto.getRandomValues(bytes);
    const reference = newReference(bytes);
    const { reporter, anonymous } = this.reporter();
    const issue = renderIssue({
      answers: this.answers,
      reporter,
      anonymous,
      app: this.opts.app,
      context: ctx,
      reference,
      startedAt: this.startedAt,
      consentVersion: CONSENT_VERSION,
    });
    const payload: Payload = {
      ...issue,
      reference,
      account: reporter.accountID,
      app: this.opts.app.id,
      ...(reporter.contact ? { contact: reporter.contact } : {}),
      attachments: [],
    };
    const result = await sendToRelay(this.opts.relay, payload);
    this.busy = false;
    if (result.ok) {
      this.reference = reference;
      this.step = "sent";
      this.opts.onSent?.(reference);
    } else {
      this.failure =
        result.reason === "unreachable" ? UI.notReachable(this.org()) : result.reason === "too-many" ? UI.tooMany : UI.refused;
    }
    this.render();
  }

  private renderSent(sheet: HTMLElement) {
    sheet.append(this.el("h2", {}, "Thank you"));
    sheet.append(this.el("p", {}, UI.sentTo(this.org())));
    sheet.append(this.el("div", {}, UI.referenceLabel), this.el("div", { class: "ref" }, this.reference));
    const done = this.el("button", { class: "primary", type: "button" }, UI.done);
    done.addEventListener("click", () => this.close());
    sheet.append(done);
  }
}

export type { FeedbackKind };
