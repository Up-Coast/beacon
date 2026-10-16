// A stand-in for the Claude runtime, for taking the documentation's
// screenshots of Inbox/index.html. It answers claude.use("db"),
// claude.use("artifact") and claude.use("user") from memory, with made-up
// sample apps and reports. It is never part of the published page:
// take.sh puts it in front of a copy of the page in a temporary folder.
//
// `?shot=<name>` picks what the page shows when the screenshot is taken:
//   dashboard   the dashboard, all apps
//   decision    the dashboard with a report that waits on a decision open
//   apps        the Apps view
//   first-run   the dashboard with no apps yet
//   form        the report form, opened as the Beacon button in an app opens it
//   kanban      the dashboard in its board layout
//   card        the board layout with a card opened
//   triage      the Triage view
//   triage-zone the Triage view with the To do bar opened
(() => {
  const shot = new URLSearchParams(location.search).get("shot") || "dashboard";
  // The page remembers its layout on the browser; the board shots ask for the board.
  try { localStorage.setItem("beacon.page.layout", shot === "kanban" || shot === "card" ? "board" : shot.startsWith("triage") ? "triage" : "list"); } catch {}
  const store = new Map();
  const put = (path, doc) => store.set(path, JSON.parse(JSON.stringify(doc)));
  // A fixed clock, so every run draws the same dates.
  const day = (n, h = 10) => new Date(Date.UTC(2026, 9, n, h, 15)).toISOString();

  if (shot !== "first-run") {
    put("apps/sample-notes", { name: "Sample Notes app", platform: "macOS", tracker: "board", folder: "sample-notes" });
    put("apps/sample-weather", { name: "Sample Weather app", platform: "iOS", tracker: "github", repository: "example-org/sample-weather", folder: "sample-weather" });
    put("apps/sample-website", { name: "Sample website", platform: "Web", tracker: "github", repository: "example-org/sample-website" });

    const notes = { id: "sample-notes", name: "Sample Notes app", platform: "macOS" };
    const weather = { id: "sample-weather", name: "Sample Weather app", platform: "iOS", repository: "example-org/sample-weather" };
    const site = { id: "sample-website", name: "Sample website", platform: "Web", repository: "example-org/sample-website" };
    const timer = { id: "sample-timer", name: "Sample Timer app", platform: "iOS", repository: "example-org/sample-timer" };
    const mac = { version: "2.3.0", build: "141", os: "macOS", osVersion: "26.1", device: "Mac15,3", locale: "en_CA", timeZone: "America/Vancouver" };
    const phone = { version: "1.8.2", build: "77", os: "iOS", osVersion: "26.0", device: "iPhone17,1", locale: "en_GB", timeZone: "Europe/London" };
    const report = (reference, app, kind, status, title, body, extra = {}) => put("reports/" + reference, {
      reference, app, kind, status, title, body: { kind, ...body }, filedAt: extra.filedAt, impact: extra.impact || "slowed",
      reporter: extra.reporter || "Tester One <tester.one@example.com>", area: extra.area || "", context: extra.context || mac,
      attachmentCount: 0, source: "beacon-inbox", ...extra,
    });

    report("BN-4A1C07", notes, "bug", "needs-human", "Exported notes lose their headings",
      { expected: "The exported file keeps each heading as a heading.", whatHappened: "Every heading comes out as plain text in the exported file.", steps: ["Open a note with two headings", "Choose File, then Export as Markdown", "Open the exported file in another editor"], reproducibility: "every-time" },
      { filedAt: day(12, 16), area: "Export", impact: "blocked", decision: "Recommend approving: the fix is small, but it changes the Markdown writer that sync also uses.", triageNote: "The exporter drops heading levels when a note has a cover image. The fix touches the shared Markdown writer used by sync too, so it waits for a decision before it is merged.", finding: { verdict: "Bug: reproduced on the second try.", intent: "Export keeps the note's structure, as the export help page says." } });
    report("BN-77E2D9", weather, "feature-request", "triaged", "Show tomorrow's forecast on the lock screen widget",
      { whatIWant: "See tomorrow's high and low on the lock screen without opening the app.", why: "I check the widget each evening to plan the next day.", idea: "A second line under today's temperature." },
      { filedAt: day(12, 9), context: phone, reporter: "Tester Two <tester.two@example.com>", impact: "noticed", issueNumber: 42, issueURL: "https://github.com/example-org/sample-weather/issues/42" });
    report("BN-1F9B3E", notes, "bug", "new", "The sidebar flickers when a folder is renamed",
      { expected: "The folder name changes in place.", whatHappened: "The whole sidebar flashes white for a moment.", steps: ["Right-click a folder", "Choose Rename", "Type a new name and press Return"], reproducibility: "sometimes" },
      { filedAt: day(13, 8), impact: "irritating" });
    report("BN-C0A515", timer, "change-request", "needs-human", "Make the lap button larger",
      { whatToChange: "The lap button is small and sits close to the stop button.", instead: "A larger lap button with more space between the two.", why: "I press stop by mistake while running." },
      { filedAt: day(11, 18), context: phone, reporter: "Tester Three <tester.three@example.com>", impact: "slowed", decision: "Recommend approving: it is a layout change with no risk to data." });
    report("BN-3D6E88", notes, "bug", "auto-fixed", "Search misses words with accents",
      { expected: "Searching for cafe finds notes that say café.", whatHappened: "Only notes spelled exactly as typed are found.", steps: ["Write a note containing café", "Search for cafe"], reproducibility: "every-time" },
      { filedAt: day(9, 14), fixCommit: "4be91c2", triageNote: "Search now ignores accents. The fix was proven by running the app and merged." });
    report("BN-9B20F4", weather, "bug", "triaging", "The radar map stays blank after waking the phone",
      { expected: "The radar map shows the latest rain.", whatHappened: "The map area stays grey until I leave the screen and come back.", steps: ["Open the radar map", "Lock the phone for a few minutes", "Unlock it"], reproducibility: "sometimes" },
      { filedAt: day(10, 7), context: phone, reporter: "Tester Two <tester.two@example.com>", issueNumber: 41, issueURL: "https://github.com/example-org/sample-weather/issues/41" });
    report("BN-E5517A", notes, "feedback", "triaged", "The new icon is lovely",
      { message: "The new icon is lovely, and it is easier to find in the Dock." },
      { filedAt: day(8, 12), impact: "noticed", reporter: "Tester Three <tester.three@example.com>" });
    report("BN-60D3B1", notes, "feature-request", "approved", "Pin a note to the top of a folder",
      { whatIWant: "Keep one note at the top of a folder, whatever the sort order.", why: "Each folder has a note of links I open every day." },
      { filedAt: day(7, 15), approval: { decision: "approved", note: "", at: day(8, 9) }, statusBeforeApproval: "triaged", column: "upnext", columnAt: day(8, 9) });
    report("BN-2C84AA", weather, "bug", "auto-fixed", "Hourly chart labels overlap in landscape",
      { expected: "Each hour's label is readable.", whatHappened: "Labels draw on top of each other when the phone is turned sideways.", steps: ["Open the hourly chart", "Turn the phone sideways"], reproducibility: "every-time" },
      { filedAt: day(5, 11), context: phone, reporter: "Tester Two <tester.two@example.com>", impact: "irritating", fixCommit: "91a0d3e", column: "deployed", columnAt: day(9, 16), issueNumber: 38, issueURL: "https://github.com/example-org/sample-weather/issues/38" });
    report("BN-8F1E02", site, "bug", "working-as-intended", "The contact form asks for a phone number",
      { expected: "The phone number is optional.", whatHappened: "The form shows a phone field.", steps: ["Open the contact page"], reproducibility: "every-time" },
      { filedAt: day(6, 13), impact: "noticed", context: { version: "", os: "", locale: "en_CA", timeZone: "America/Toronto" }, triageNote: "The phone field is already optional; the form marks only the email as required." });
  }

  const listeners = [];
  const notify = () => listeners.forEach((run) => run());
  const collection = (path) => {
    const docs = () => [...store.entries()]
      .filter(([key]) => key.startsWith(path + "/") && !key.slice(path.length + 1).includes("/"))
      .map(([key, value]) => ({ id: key.slice(path.length + 1), data: () => value }));
    const query = {
      orderBy: () => query, limit: () => query, where: () => query,
      get: async () => ({ docs: docs() }),
      onSnapshot(next) { const run = () => next({ docs: docs() }); listeners.push(run); setTimeout(run, 30); return () => {}; },
    };
    return query;
  };
  const doc = (path) => ({
    get: async () => ({ exists: store.has(path), data: () => store.get(path) }),
    set: async (value) => { put(path, value); notify(); },
    update: async (value) => { put(path, { ...(store.get(path) || {}), ...value }); notify(); },
    delete: async () => { store.delete(path); notify(); },
    collection: (name) => collection(path + "/" + name),
  });
  window.claude = {
    use: async (name) => name === "db" ? { doc, collection }
      : name === "artifact" ? { publish: async () => {} }
      : name === "user" ? { canEdit: async () => true }
      : null,
  };

  // Put the page into the state the screenshot shows, once it has drawn.
  window.addEventListener("load", () => setTimeout(() => {
    const click = (selector) => { const n = document.querySelector(selector); if (n) n.click(); };
    if (shot === "decision") {
      const row = [...document.querySelectorAll("#queue details")].find((d) => d.querySelector(".decide-line"));
      if (row) row.open = true;
    }
    if (shot === "apps") click('.switch [data-view="apps"]');
    if (shot === "triage-zone") click('.zone[data-key="upnext"] .zonebar');
    if (shot === "card") click('.kcol[data-col="todo"] .card .open');
  }, 300));
})();
