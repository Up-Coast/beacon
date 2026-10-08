// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";
import { Beacon } from "../src/index";

describe("the sheet", () => {
  afterEach(() => Beacon.unmount());

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
    expect(launch.textContent).toContain("Report a problem");
    expect(launch.querySelector("svg")).not.toBeNull();
    launch.click();
    const titles = [...root.querySelectorAll("button.kind b")].map((b) => b.textContent);
    expect(titles).toEqual(["Something's broken", "Something's missing", "Change request", "Something else"]);
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
    const kinds = [...root.querySelectorAll("button.kind")] as HTMLButtonElement[];
    kinds[3]!.click();
    ([...root.querySelectorAll("button.primary")].find((b) => /understand/.test(b.textContent!)) as HTMLButtonElement).click();
    const message = root.querySelector("#beacon-message") as HTMLTextAreaElement;
    message.value = "Thank you, this is really useful";
    message.dispatchEvent(new Event("input"));
    ([...root.querySelectorAll("button.primary")].find((b) => b.textContent === "Next") as HTMLButtonElement).click();
    ([...root.querySelectorAll("button.primary")].find((b) => b.textContent === "Send") as HTMLButtonElement).click();
    await vi.waitFor(() => expect(root.textContent).toContain("Thank you"));
    const body = JSON.parse((fetchMock.mock.calls[0] as unknown as [string, RequestInit])[1].body as string);
    expect(body.app).toBe("x");
    expect(body.labels).toContain("type:feedback");
    expect(body.reference).toMatch(/^BN-[0-9A-F]{6}$/);
    vi.unstubAllGlobals();
  });
});
