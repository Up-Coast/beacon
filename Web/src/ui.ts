import { blockingIssues, checkCompleteness } from "./completeness";
import { BEACON_ICON_SVG } from "./icon";
import { collectContext } from "./context";
import { displaySize, newReference, renderIssue } from "./render";
import { sendToRelay, type RelayConfig } from "./transport";
import {
  ACCEPTED_EXTENSIONS,
  FIELD_HINTS as H,
  FIELD_LABELS as F,
  IMPACT_WORDS,
  KIND_WORDS,
  MAX_FILE_BYTES,
  MAX_SEND_BASE64,
  MAX_TOTAL_BYTES,
  REPRODUCIBILITY_WORDS,
  UI,
  refusalFor,
} from "./wording";
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

export const CONSENT_VERSION = "2026-10-08.anonymous.2";

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
  /** How many pixels higher than its usual spot the floating button sits, to clear a bar along the bottom of the page. Default 0. */
  bottomOffset?: number;
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


interface Identity {
  name: string;
  contact: string;
  /** The reporter chose "Send without my name". */
  decided: boolean;
}

function readIdentity(): Identity {
  try {
    const raw = JSON.parse(get("identity") ?? "{}") as Partial<Identity>;
    return { name: raw.name ?? "", contact: raw.contact ?? "", decided: raw.decided === true };
  } catch {
    return { name: "", contact: "", decided: false };
  }
}

/** The floating button's distance from the bottom of the window: the usual 24px, raised by `bottomOffset`. */
export function launchBottom(bottomOffset?: number): number {
  const offset = Number.isFinite(bottomOffset) ? Math.max(0, bottomOffset as number) : 0;
  return 24 + offset;
}

const CSS = `
:host{all:initial;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;color:#1f2937}
*{box-sizing:border-box}
.launch{position:fixed;z-index:2147483000;width:48px;height:48px;padding:0;border:0;background:none;cursor:pointer;filter:drop-shadow(0 2px 4px rgba(0,0,0,.3));border-radius:12px}
.launch svg{display:block;width:100%;height:100%}
.launch.right{right:24px}.launch.left{left:24px}
.launch:hover{filter:drop-shadow(0 3px 6px rgba(0,0,0,.4))}
.launch:focus-visible,button:focus-visible,input:focus-visible,textarea:focus-visible,select:focus-visible{outline:2px solid #2563eb;outline-offset:2px}
dialog{border:0;border-radius:14px;padding:0;width:min(620px,calc(100vw - 24px));max-height:calc(100vh - 24px);box-shadow:0 20px 60px rgba(0,0,0,.35);color:#1f2937;background:#fff}
dialog::backdrop{background:rgba(17,24,39,.55)}
.frame{display:flex;flex-direction:column;max-height:calc(100vh - 24px)}
.sheet{padding:24px;overflow:auto;flex:1}
.foot{display:flex;gap:10px;justify-content:space-between;align-items:center;padding:14px 24px;border-top:1px solid #e5e7eb}
h2{font:700 22px system-ui;margin:0 0 6px}h3{font:600 15px system-ui;margin:0}
p{margin:0 0 12px;line-height:1.45;font-size:14px}.sub{color:#6b7280}.hint{color:#6b7280;font-size:13px;margin:0 0 6px;line-height:1.4}
a{color:#2563eb}
label{display:block;font:600 13px system-ui;margin:10px 0 5px}label.choice{font:14px system-ui;margin:4px 0}
h3{margin:0 0 4px}
.kinds{display:grid;gap:10px;margin-top:12px}
.kind{text-align:left;border:1px solid #d1d5db;background:#f9fafb;border-radius:10px;padding:14px;cursor:pointer;font:inherit}
.kind:hover{border-color:#2563eb;background:#eff6ff}.kind b{display:block;font-size:15px}.kind span{font-size:13px;color:#4b5563}
.block{margin:0 0 20px}
textarea,input[type=text],input[type=email]{width:100%;font:14px system-ui;padding:9px 10px;border:1px solid #d1d5db;border-radius:8px;background:#f3f4f6;color:#111827}
textarea{min-height:64px;resize:vertical}
.choice{display:flex;gap:8px;align-items:flex-start;font-size:14px;margin:4px 0;line-height:1.4}.choice input{margin-top:3px}
.box{border:1px solid #d1d5db;border-radius:10px;padding:12px 14px;margin:0 0 16px;font-size:14px;background:#f9fafb}
.box ul{margin:6px 0 0}
.warn{color:#b45309;font-size:13px;margin:6px 0}
ul{margin:0 0 12px;padding-left:20px;font-size:14px;line-height:1.5}
.primary{background:#2563eb;color:#fff;border:0;border-radius:8px;padding:10px 20px;font:600 14px system-ui;cursor:pointer}
.primary:disabled{background:#9ca3af;cursor:not-allowed}
.ghost{background:transparent;border:0;color:#2563eb;font:600 14px system-ui;cursor:pointer;padding:10px}
.small{background:#fff;border:1px solid #d1d5db;border-radius:8px;padding:7px 12px;font:600 13px system-ui;cursor:pointer;color:#111827}
.small:hover{background:#f3f4f6}
.btns{display:flex;flex-wrap:wrap;gap:8px;margin:8px 0}
.drop{border:1.5px dashed #9ca3af;border-radius:10px;height:64px;display:flex;align-items:center;justify-content:center;color:#6b7280;font-size:14px;margin:8px 0}
.drop.over{border-color:#2563eb;background:rgba(37,99,235,.1);color:#2563eb}
.file{display:flex;gap:8px;align-items:center;font-size:13px;margin:4px 0}.file span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.file .x{margin-left:auto;background:none;border:0;cursor:pointer;color:#6b7280;font-size:16px}
.row2{display:flex;gap:12px;font-size:14px;margin:0 0 12px}.row2 b{min-width:70px;color:#6b7280;font-weight:600}
details{font-size:14px;margin:0 0 14px}summary{cursor:pointer;font-weight:600}
pre{white-space:pre-wrap;word-break:break-word;font:12px ui-monospace,Menlo,monospace;background:#f3f4f6;border-radius:8px;padding:10px;max-height:260px;overflow:auto;margin:8px 0 0}
table{border-collapse:collapse;font-size:13px;width:100%;margin-top:8px}td{padding:4px 6px;border-bottom:1px solid #e5e7eb;vertical-align:top;word-break:break-word}td:first-child{color:#6b7280;white-space:nowrap}
.err{color:#b91c1c;font-size:13px;margin:0 0 10px}
.ref{font:700 22px ui-monospace,Menlo,monospace;letter-spacing:.05em;margin:6px 0 14px;user-select:all}
.close{position:absolute;right:14px;top:12px;background:transparent;border:0;font-size:24px;line-height:1;cursor:pointer;color:#6b7280}
`;

type Step = "consent" | "pick" | "form" | "review" | "sent";

export class BeaconSheet {
  private host: HTMLElement;
  private root: ShadowRoot;
  private dialog: HTMLDialogElement;
  private launch: HTMLButtonElement | null = null;
  private step: Step = "pick";
  private answers: Answers = { kind: "bug", impact: "irritating", steps: [""] };
  private identity: Identity = readIdentity();
  private files: File[] = [];
  private problem = "";
  private blocking: string[] = [];
  private advisory: string[] = [];
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
      b.style.bottom = `${launchBottom(opts.bottomOffset)}px`;
      b.setAttribute("aria-label", UI.button);
      b.title = UI.button;
      b.innerHTML = opts.icon ?? BEACON_ICON_SVG;
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
    this.identity = readIdentity();
    this.files = [];
    this.problem = "";
    this.blocking = [];
    this.failure = "";
    this.answers = { kind: "bug", impact: "irritating", steps: [""] };
    this.step = get("consent") === CONSENT_VERSION ? "pick" : "consent";
    this.render();
    if (!this.dialog.open) this.dialog.showModal();
    if (this.launch) this.launch.style.display = "none";
  }

  close() {
    if (this.dialog.open) this.dialog.close();
  }

  private onClosed() {
    this.step = "pick";
    if (this.launch) this.launch.style.display = "";
  }

  private org(): string {
    return this.opts.organizationName ?? "the team";
  }

  private saveIdentity() {
    if (this.opts.reporter) return;
    set("identity", JSON.stringify(this.identity));
  }

  private reporter(): { reporter: Reporter; anonymous: boolean } {
    const given = this.opts.reporter;
    const contact = this.identity.contact.trim();
    if (given) {
      return { reporter: { ...given, contact: contact || given.contact }, anonymous: false };
    }
    const without = this.identity.decided && !this.identity.name && !this.identity.contact;
    return {
      reporter: {
        accountID: anonymousId(),
        displayName: without ? undefined : this.identity.name.trim() || undefined,
        contact: without ? undefined : contact || undefined,
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

  private button(cls: string, label: string, on: () => void, disabled = false) {
    const b = this.el("button", { class: cls, type: "button" }, label);
    b.disabled = disabled;
    b.addEventListener("click", on);
    return b;
  }

  private render() {
    const frame = this.el("div", { class: "frame" });
    const sheet = this.el("div", { class: "sheet" });
    const foot = this.el("div", { class: "foot" });
    const x = this.el("button", { class: "close", type: "button", "aria-label": UI.close }, "×");
    x.addEventListener("click", () => this.close());
    if (this.step === "consent") this.renderConsent(sheet, foot);
    else if (this.step === "pick") this.renderPick(sheet, foot);
    else if (this.step === "form") this.renderForm(sheet, foot);
    else if (this.step === "review") this.renderReview(sheet, foot);
    else this.renderSent(sheet, foot);
    frame.append(sheet, foot);
    frame.style.position = "relative";
    frame.append(x);
    this.dialog.replaceChildren(frame);
  }

  private title(sheet: HTMLElement, title: string, subtitle?: string) {
    sheet.append(this.el("h2", {}, title));
    if (subtitle) sheet.append(this.el("p", { class: "sub" }, subtitle));
  }

  // MARK: Consent

  private renderConsent(sheet: HTMLElement, foot: HTMLElement) {
    this.title(sheet, UI.consentHeadline, UI.consentSubtitle);
    const ul = this.el("ul");
    for (const point of UI.consentPoints(this.org())) ul.append(this.el("li", {}, point));
    sheet.append(ul);
    if (!this.opts.reporter) this.identityBlock(sheet);
    foot.append(
      this.button("ghost", UI.cancel, () => this.close()),
      this.button("primary", UI.consentAccept, () => {
        this.saveIdentity();
        set("consent", CONSENT_VERSION);
        this.step = "pick";
        this.render();
      }),
    );
  }

  /** Who it is from, asked once and remembered on this browser; same words as the Mac and iPhone sheet. */
  private identityBlock(sheet: HTMLElement) {
    const id = this.identity;
    const block = this.el("div", { class: "block" });
    block.append(this.el("h3", {}, UI.identityLabel));
    if (id.decided && !id.name && !id.contact) {
      block.append(this.el("p", { class: "hint" }, UI.withoutNameNote));
      block.append(
        this.button("small", UI.addName, () => {
          id.decided = false;
          this.render();
        }),
      );
      sheet.append(block);
      return;
    }
    const input = (label: string, key: "name" | "contact", type: string) => {
      const wrap = this.el("div", { class: "block" });
      wrap.append(this.el("label", { for: `beacon-id-${key}` }, label));
      const i = this.el("input", { id: `beacon-id-${key}`, type });
      i.value = id[key];
      i.addEventListener("input", () => {
        id[key] = i.value;
        this.saveIdentity();
      });
      wrap.append(i);
      return wrap;
    };
    block.append(input(UI.nameLabel, "name", "text"), input(UI.emailLabel, "contact", "email"));
    const btns = this.el("div", { class: "btns" });
    btns.append(
      this.button("small", UI.withoutName, () => {
        id.name = "";
        id.contact = "";
        id.decided = true;
        this.saveIdentity();
        this.render();
      }),
    );
    if (id.name || id.contact) {
      btns.append(
        this.button("small", UI.forget, () => {
          this.identity = { name: "", contact: "", decided: false };
          try {
            store()?.removeItem(STORE + "identity");
          } catch {
            /* nothing to clear */
          }
          this.render();
        }),
      );
    }
    block.append(btns);
    sheet.append(block);
  }

  // MARK: Pick

  private renderPick(sheet: HTMLElement, foot: HTMLElement) {
    sheet.append(this.el("h2", {}, UI.pickTitle));
    const intro = this.el("p", { class: "sub" });
    const link = this.el("a", { href: UI.beaconHome, target: "_blank", rel: "noopener" }, UI.introLink);
    intro.append(document.createTextNode(UI.intro(this.opts.organizationName ?? "")), link, document.createTextNode(UI.introTail));
    sheet.append(intro);
    const list = this.el("div", { class: "kinds" });
    for (const kind of KINDS) {
      const b = this.el("button", { class: "kind", type: "button" });
      b.append(this.el("b", {}, KIND_WORDS[kind].title), this.el("span", {}, KIND_WORDS[kind].blurb));
      b.addEventListener("click", () => {
        this.answers = { ...this.answers, kind, steps: this.answers.steps ?? [""] };
        this.step = "form";
        this.render();
      });
      list.append(b);
    }
    sheet.append(list);
    foot.append(this.el("span"), this.button("ghost", UI.cancel, () => this.close()));
  }

  // MARK: Form

  private block(sheet: HTMLElement, label: string, hint?: string) {
    const b = this.el("div", { class: "block" });
    b.append(this.el("h3", {}, label));
    if (hint) b.append(this.el("p", { class: "hint" }, hint));
    sheet.append(b);
    return b;
  }

  private text(sheet: HTMLElement, key: keyof Answers & string, label: string, hint?: string, rows = 3) {
    const b = this.block(sheet, label, hint);
    const area = this.el("textarea", { id: `beacon-${key}`, "aria-label": label, rows: String(rows) });
    area.value = ((this.answers[key] as string | undefined) ?? "") as string;
    area.addEventListener("input", () => {
      (this.answers as unknown as Record<string, unknown>)[key] = area.value;
    });
    b.append(area);
  }

  private choice<T extends string>(
    sheet: HTMLElement,
    name: string,
    label: string,
    hint: string | undefined,
    values: readonly T[],
    words: Record<T, string>,
    current: T,
    on: (v: T) => void,
  ) {
    const b = this.block(sheet, label, hint);
    for (const v of values) {
      const wrap = this.el("label", { class: "choice" });
      const r = this.el("input", { type: "radio", name: `beacon-${name}`, value: v });
      r.checked = current === v;
      r.addEventListener("change", () => on(v));
      wrap.append(r, document.createTextNode(words[v]));
      b.append(wrap);
    }
  }

  private renderForm(sheet: HTMLElement, foot: HTMLElement) {
    const a = this.answers;
    this.title(sheet, KIND_WORDS[a.kind].title, KIND_WORDS[a.kind].blurb);
    if (a.kind === "bug") {
      this.text(sheet, "expected", F.expected, H.expected);
      this.text(sheet, "whatHappened", F.whatHappened, H.whatHappened);
      const b = this.block(sheet, F.steps, H.steps);
      const steps = this.el("textarea", { id: "beacon-steps", "aria-label": F.steps, rows: "3" });
      steps.value = (a.steps ?? []).join("\n");
      steps.addEventListener("input", () => (a.steps = steps.value.split("\n")));
      b.append(steps);
      this.choice(sheet, "repro", F.reproducibility, undefined, REPRODUCIBILITIES, REPRODUCIBILITY_WORDS, a.reproducibility ?? "unknown", (v) => (a.reproducibility = v));
    } else if (a.kind === "feature-request") {
      this.text(sheet, "whatIWant", F.whatIWant, H.whatIWant);
      this.text(sheet, "why", F.why, H.why);
      this.text(sheet, "idea", F.idea, H.idea);
    } else if (a.kind === "change-request") {
      this.text(sheet, "whatToChange", F.whatToChange, H.whatToChange);
      this.text(sheet, "instead", F.instead);
      this.text(sheet, "why", F.changeWhy, undefined, 2);
    } else {
      this.text(sheet, "message", F.message, undefined, 5);
    }
    this.choice(sheet, "impact", F.impact, H.impact, IMPACTS, IMPACT_WORDS, a.impact, (v) => (a.impact = v));
    this.attachments(sheet);
    if (this.opts.reporter) {
      const b = this.block(sheet, "How can we reach you? (optional)", H.contact);
      const i = this.el("input", { type: "text", "aria-label": "How can we reach you?" });
      i.value = this.identity.contact;
      i.addEventListener("input", () => (this.identity.contact = i.value));
      b.append(i);
    } else {
      this.identityBlock(sheet);
    }
    if (this.blocking.length) {
      const box = this.el("div", { class: "box", role: "alert" });
      box.append(this.el("h3", {}, UI.blockingTitle));
      const ul = this.el("ul");
      for (const m of this.blocking) ul.append(this.el("li", {}, m));
      box.append(ul);
      sheet.append(box);
    }
    foot.append(
      this.button("ghost", UI.back, () => {
        this.step = "pick";
        this.render();
      }),
      this.button("primary", UI.next, () => this.toReview()),
    );
  }

  private toReview() {
    this.blocking = blockingIssues(this.answers).map((i) => i.message);
    if (this.blocking.length) {
      this.render();
      return;
    }
    this.advisory = checkCompleteness(this.answers)
      .filter((i) => !i.blocking)
      .map((i) => i.message);
    const bytes = new Uint8Array(3);
    crypto.getRandomValues(bytes);
    this.reference = newReference(bytes);
    this.saveIdentity();
    this.failure = "";
    this.step = "review";
    this.render();
  }

  // MARK: Attachments

  private attachments(sheet: HTMLElement) {
    const b = this.block(sheet, UI.attachTitle, UI.attachHint);
    const input = this.el("input", { type: "file", multiple: "" });
    input.style.display = "none";
    input.addEventListener("change", () => {
      this.addFiles([...(input.files ?? [])]);
    });
    const btns = this.el("div", { class: "btns" });
    btns.append(this.button("small", UI.addFile, () => input.click()), input);
    const drop = this.el("div", { class: "drop" }, UI.dropHere);
    drop.addEventListener("dragover", (e) => {
      e.preventDefault();
      drop.classList.add("over");
    });
    drop.addEventListener("dragleave", () => drop.classList.remove("over"));
    drop.addEventListener("drop", (e) => {
      e.preventDefault();
      drop.classList.remove("over");
      this.addFiles([...(e.dataTransfer?.files ?? [])]);
    });
    b.append(btns, drop);
    if (this.problem) b.append(this.el("p", { class: "warn", role: "alert" }, this.problem));
    this.files.forEach((f, i) => {
      const line = this.el("div", { class: "file" });
      const x = this.el("button", { class: "x", type: "button", "aria-label": UI.remove, title: UI.remove }, "×");
      x.addEventListener("click", () => {
        this.files.splice(i, 1);
        this.render();
      });
      line.append(this.el("span", {}, f.name), this.el("span", { class: "sub" }, displaySize(f.size)), x);
      b.append(line);
    });
  }

  private addFiles(picked: File[]) {
    this.problem = "";
    const added: File[] = [];
    for (const f of picked) {
      const ext = f.name.includes(".") ? f.name.split(".").pop()!.toLowerCase() : "";
      if (!ACCEPTED_EXTENSIONS.has(ext)) {
        this.problem = refusalFor(f.name);
        continue;
      }
      if (f.size > MAX_FILE_BYTES) {
        this.problem = `${f.name} is ${Math.round(f.size / 1024 / 1024)} MB, over the ${MAX_FILE_BYTES / 1024 / 1024} MB limit for one file.`;
        continue;
      }
      const total = [...this.files, ...added].reduce((n, x) => n + x.size, 0) + f.size;
      if (total > MAX_TOTAL_BYTES) {
        this.problem = `That would take the report over ${MAX_TOTAL_BYTES / 1024 / 1024} MB in total. Removing something else first will make room.`;
        continue;
      }
      added.push(f);
    }
    this.files.push(...added);
    this.render();
  }

  private async encode(file: File): Promise<string> {
    const bytes = new Uint8Array(await file.arrayBuffer());
    let binary = "";
    for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
    return btoa(binary);
  }

  // MARK: Review

  private issue(ctx: ReturnType<typeof collectContext>) {
    const { reporter, anonymous } = this.reporter();
    const issue = renderIssue({
      answers: this.answers,
      reporter,
      anonymous,
      app: this.opts.app,
      context: ctx,
      reference: this.reference,
      startedAt: this.startedAt,
      consentVersion: CONSENT_VERSION,
      attachments: this.files.map((f) => ({ filename: f.name, bytes: f.size })),
    });
    return { issue, reporter, anonymous };
  }

  private renderReview(sheet: HTMLElement, foot: HTMLElement) {
    this.title(sheet, UI.reviewTitle, UI.reviewSubtitle);
    const ctx = collectContext(this.opts.hostNotes?.());
    const { issue, reporter, anonymous } = this.issue(ctx);
    const line = (k: string, v: string) => {
      const r = this.el("div", { class: "row2" });
      r.append(this.el("b", {}, k), this.el("span", {}, v));
      sheet.append(r);
    };
    line(UI.goingTo, this.org());
    const given = [reporter.displayName, reporter.contact].filter(Boolean).join(", ");
    line(UI.from, anonymous ? given || UI.anonymousFrom : (reporter.displayName ?? reporter.accountID));
    if (this.advisory.length) {
      const box = this.el("div", { class: "box" });
      for (const m of this.advisory) box.append(this.el("p", {}, m));
      sheet.append(box);
    }
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
    const details = this.el("details");
    details.append(this.el("summary", {}, UI.everything), table, this.el("pre", {}, issue.body));
    sheet.append(details);
    if (this.failure) sheet.append(this.el("p", { class: "err", role: "alert" }, this.failure));
    foot.append(
      this.button("ghost", UI.back, () => {
        this.step = "form";
        this.render();
      }),
      this.button("primary", this.busy ? UI.sending : UI.send, () => void this.send(ctx), this.busy),
    );
  }

  private async send(ctx: ReturnType<typeof collectContext>) {
    this.busy = true;
    this.failure = "";
    this.render();
    const { issue, reporter } = this.issue(ctx);
    const attachments = await Promise.all(this.files.map(async (f) => ({ filename: f.name, base64: await this.encode(f) })));
    if (attachments.reduce((n, a) => n + a.base64.length, 0) > MAX_SEND_BASE64) {
      this.busy = false;
      this.failure = UI.tooLarge;
      this.render();
      return;
    }
    const payload: Payload = {
      ...issue,
      reference: this.reference,
      account: reporter.accountID,
      app: this.opts.app.id,
      ...(reporter.contact ? { contact: reporter.contact } : {}),
      attachments,
    };
    const result = await sendToRelay(this.opts.relay, payload);
    this.busy = false;
    if (result.ok) {
      this.step = "sent";
      this.opts.onSent?.(this.reference);
    } else {
      this.failure =
        result.reason === "unreachable" ? UI.notReachable(this.org()) : result.reason === "too-many" ? UI.tooMany : UI.refused;
    }
    this.render();
  }

  private renderSent(sheet: HTMLElement, foot: HTMLElement) {
    this.title(sheet, UI.sentTitle);
    sheet.append(this.el("p", {}, UI.sentTo(this.org())));
    sheet.append(this.el("div", { class: "sub" }, UI.referenceLabel), this.el("div", { class: "ref" }, this.reference));
    foot.append(this.el("span"), this.button("primary", UI.done, () => this.close()));
  }
}

export type { FeedbackKind };
