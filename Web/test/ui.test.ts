// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { Beacon } from "../src/index";
import { clampToViewport, launchBottom } from "../src/ui";

describe("the sheet", () => {
  afterEach(() => {
    Beacon.unmount();
    localStorage.clear();
  });

  it("raises the floating button by bottomOffset, and only upward", () => {
    Beacon.mount({
      app: { id: "ca.upcoast.portal", name: "Up Coast" },
      relay: { url: "https://r.test/f", token: "t" },
      bottomOffset: 40,
    });
    const launch = document.querySelector("[data-beacon]")!.shadowRoot!.querySelector("button.launch") as HTMLButtonElement;
    expect(launch.style.bottom).toBe("64px");
    expect(launchBottom()).toBe(24);
    expect(launchBottom(-10)).toBe(24);
  });

  it("keeps a dragged button inside the window", () => {
    expect(clampToViewport(-20, 5000, 48, 800, 600)).toEqual({ x: 0, y: 552 });
    expect(clampToViewport(900, 100, 48, 800, 600)).toEqual({ x: 752, y: 100 });
  });

  it("moves the button when it is dragged, remembers where, and does not open the sheet on release", () => {
    HTMLDialogElement.prototype.showModal = function () {
      this.setAttribute("open", "");
    };
    Beacon.mount({
      app: { id: "ca.upcoast.portal", name: "Up Coast" },
      relay: { url: "https://r.test/f", token: "t" },
    });
    const root = document.querySelector("[data-beacon]")!.shadowRoot!;
    const launch = root.querySelector("button.launch") as HTMLButtonElement;
    const fire = (type: string, x: number, y: number) =>
      launch.dispatchEvent(new MouseEvent(type, { clientX: x, clientY: y, button: 0, bubbles: true }));
    fire("pointerdown", 10, 10);
    fire("pointermove", 100, 120);
    fire("pointerup", 100, 120);
    launch.click();
    expect(launch.style.left).toBe("90px");
    expect(launch.style.top).toBe("110px");
    expect(launch.style.right).toBe("auto");
    expect(root.querySelector("dialog")!.hasAttribute("open")).toBe(false);
    expect(localStorage.getItem("beacon.buttonAt") ?? JSON.stringify(Object.entries(localStorage))).toContain("buttonAt");
  });

  it("puts a Report a problem button on the page and opens the kind picker", () => {
    HTMLDialogElement.prototype.showModal = function () {
      this.setAttribute("open", "");
    };
    const sheet = Beacon.mount({
      app: { id: "ca.upcoast.portal", name: "Up Coast" },
      relay: { url: "https://r.test/f", token: "t" },
      organizationName: "the Up Coast team",
    });
    const host = document.querySelector("[data-beacon]") as HTMLElement;
    const root = host.shadowRoot!;
    const launch = root.querySelector("button.launch") as HTMLButtonElement;
    expect(launch.getAttribute("aria-label")).toBe("Report a problem");
    expect(launch.textContent?.trim()).toBe("");
    expect(launch.querySelector("svg")).not.toBeNull();
    launch.click();
    ([...root.querySelectorAll("button.primary")].find((b) => /understand/.test(b.textContent!)) as HTMLButtonElement).click();
    const titles = [...root.querySelectorAll("button.kind b")].map((b) => b.textContent);
    expect(titles).toEqual(["Something's broken", "Something's missing", "Change request", "Something else", "I have a feedback document"]);
    void sheet;
  });

  it("walks feedback through consent, the form and the relay", async () => {
    HTMLDialogElement.prototype.showModal = function () {
      this.setAttribute("open", "");
    };
    const fetchMock = vi.fn(async () => new Response("{}", { status: 201 }));
    vi.stubGlobal("fetch", fetchMock);
    Beacon.mount({ app: { id: "x", name: "X" }, relay: { url: "https://r.test/f" }, organizationName: "the team" });
    const root = (document.querySelector("[data-beacon]") as HTMLElement).shadowRoot!;
    (root.querySelector("button.launch") as HTMLButtonElement).click();
    ([...root.querySelectorAll("button.primary")].find((b) => /understand/.test(b.textContent!)) as HTMLButtonElement).click();
    const kinds = [...root.querySelectorAll("button.kind")] as HTMLButtonElement[];
    kinds[3]!.click();
    const message = root.querySelector("#beacon-message") as HTMLTextAreaElement;
    message.value = "Thank you, this is really useful";
    message.dispatchEvent(new Event("input"));
    ([...root.querySelectorAll("button.primary")].find((b) => b.textContent === "Next") as HTMLButtonElement).click();
    ([...root.querySelectorAll("button.primary")].find((b) => b.textContent === "Send") as HTMLButtonElement).click();
    await vi.waitFor(() => expect(root.textContent).toContain("Sent \u2014 thank you"));
    const body = JSON.parse((fetchMock.mock.calls[0] as unknown as [string, RequestInit])[1].body as string);
    expect(body.app).toBe("x");
    expect(body.labels).toContain("type:feedback");
    expect(body.reference).toMatch(/^BN-[0-9A-F]{6}$/);
    vi.unstubAllGlobals();
  });
});
