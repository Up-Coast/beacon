#!/usr/bin/env python3
"""Mirror GitHub issues onto the Beacon page's board.

The board (the `reports` collection of the page's database) is a view of the
GitHub issues labelled `beacon`. This script reads both, works out which board
documents are missing or out of date, and writes the writes into batch files.
It reads GitHub with `gh` and the board from files the caller saved with the
ArtifactData tool (`list` with `out_dir`). It never writes to the board itself;
the caller sends each batch file's `writes` with the tool's `batch` action.

    python3 Scripts/mirror-board.py --reports <dir> --apps <dir> --out <dir> \
        [--versions <file>] [--dry-run]

--reports   directory of report documents, one <reference>.json each
--apps      directory of app documents, one <id>.json each
--out       where the batch files go (batch-01.json ...) with summary.json
--versions  optional JSON map {reference: version}; a document not in it is
            assumed to be at version 1 (a document this script or the page has
            written since is at a higher one: pass the version, or the write is
            refused and names the current version)
--dry-run   print the summary and write nothing

What it decides, from the issue's state and labels alone (no judgement):

  a beacon/<n>-* branch, or an open pull request naming the issue
                                                     In progress, with the pull request link
  a merged pull request naming the issue             Done, with the merge commit
                                                     (a report flagged Blocked or Waiting for human only gets the link)

  open, needs-human / needs-info / cannot-reproduce /
        expectation-mismatch / working-as-intended   status of that name
  open, triaged                                      status triaged, column todo
  open, backlog                                      status backlog, column backlog
  open, none of those                                left alone: it still has
                                                     to be triaged
  closed with wontfix or declined                    status declined
  closed as a duplicate                              status duplicate
  closed as not planned                              status closed
  closed, working-as-intended                        status working-as-intended
  closed, anything else                              status auto-fixed, column done

A board document is only moved up: a document already at a more specific
status than the labels say, or one the owner has decided on (it carries an
`approval`), has edited by hand (`editedAt`) or the pickup is working
(todo, approved, triaging), is left alone.
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys

# label -> (status, column); first match in this order wins
OPEN_LABELS = [
    ("needs-human", ("needs-human", "todo")),
    ("needs-info", ("needs-info", "todo")),
    ("cannot-reproduce", ("cannot-reproduce", "todo")),
    ("expectation-mismatch", ("expectation-mismatch", "todo")),
    ("working-as-intended", ("working-as-intended", None)),
    ("auto-fixed", ("auto-fixed", "done")),
    ("backlog", ("backlog", "backlog")),
    ("triaged", ("triaged", "todo")),
]
RANK = {"filed": 0, "new": 0, "triaged": 1}  # anything else is 2
HELD = {"approved", "todo", "triaging", "declined", "feedback-closed"}
BATCH = 50
BODY_LIMIT = 6000


def gh_issues(repo):
    out = subprocess.run(
        ["gh", "issue", "list", "--repo", repo, "--label", "beacon", "--state", "all",
         "--limit", "2000", "--json", "number,title,state,stateReason,labels,body,url,createdAt,author"],
        check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def app_prefix(app):
    """Two or three capital letters: the app's `prefix`, else the initials of its
    name, else the first three letters of a one-word name (Up Coast platform is
    UCP, Dayletter is DAY). Inbox/index.html computes the same."""
    own = re.sub(r"[^A-Za-z]", "", str(app.get("prefix") or "")).upper()[:3]
    if len(own) >= 2:
        return own
    words = [w for w in re.split(r"[^A-Za-z]+", str(app.get("name") or "")) if w]
    letters = "".join(w[0] for w in words) if len(words) > 1 else (words[0] if words else "")
    return letters.upper()[:3] or "BN"


def gh_work(repo):
    """Per issue number: the beacon/<n>-* branches and the pull requests that name it.

    A pull request names an issue by its branch (beacon/<n>-slug) or by a
    "#<n>" in its title or body (Closes #n). One call each for branches and
    pull requests, however many issues the repository has.
    """
    work = {}
    refs = subprocess.run(
        ["gh", "api", "repos/%s/git/matching-refs/heads/beacon/" % repo, "--paginate", "--jq", ".[].ref"],
        capture_output=True, text=True).stdout.split()
    for ref in refs:
        m = re.match(r"refs/heads/beacon/(\d+)-", ref)
        if m:
            work.setdefault(int(m.group(1)), {"branch": ref[len("refs/heads/"):], "prs": []})
    prs = json.loads(subprocess.run(
        ["gh", "pr", "list", "--repo", repo, "--state", "all", "--limit", "300", "--json",
         "number,url,state,isDraft,headRefName,title,body,mergeCommit"],
        capture_output=True, text=True).stdout or "[]")
    for pr in prs:
        numbers = set()
        m = re.match(r"beacon/(\d+)-", pr.get("headRefName") or "")
        if m:
            numbers.add(int(m.group(1)))
        for n in re.findall(r"(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)", (pr.get("title") or "") + " " + (pr.get("body") or ""), re.I):
            numbers.add(int(n))
        for n in numbers:
            work.setdefault(n, {"branch": None, "prs": []})["prs"].append(pr)
    return work


def link_change(d, issue, work):
    """What a branch or pull request says about a report, with no judgement.

    A merged pull request: Done, with the merge commit. An open one, or a
    branch with no pull request: In progress. A report the owner flagged
    Blocked or Waiting for human keeps its status; only the link is recorded.
    """
    if not work or d.get("status") in ("declined", "duplicate", "closed", "feedback-closed", "working-as-intended", "deployed"):
        return {}
    prs = sorted(work["prs"], key=lambda p: (p["state"] != "MERGED", p["state"] != "OPEN", -p["number"]))
    pr = prs[0] if prs else None
    change = {}
    if pr and pr["state"] in ("MERGED", "OPEN"):
        state = "merged" if pr["state"] == "MERGED" else ("draft" if pr.get("isDraft") else "open")
        link = {"number": pr["number"], "url": pr["url"], "state": state}
        if d.get("pullRequest") != link:
            change["pullRequest"] = link
    paused = {"Blocked", "Waiting for human"} & set(d.get("flags") or [])
    if pr and pr["state"] == "MERGED":
        commit = (pr.get("mergeCommit") or {}).get("oid")
        if commit and d.get("fixCommit") != commit:
            change["fixCommit"] = commit
        if d.get("status") != "auto-fixed" or d.get("column") != "done":
            change.update(status="auto-fixed", column="done")
    elif not paused and d.get("status") != "auto-fixed" and issue["state"].upper() == "OPEN":
        if (pr and pr["state"] == "OPEN") or work.get("branch"):
            if d.get("status") != "triaging" or d.get("column") != "inprogress":
                change.update(status="triaging", column="inprogress")
    return change


def load_dir(path):
    docs = {}
    for f in glob.glob(os.path.join(path, "*.json")):
        with open(f) as fh:
            docs[os.path.splitext(os.path.basename(f))[0]] = json.load(fh)
    return docs


def label_value(labels, prefix):
    for l in labels:
        if l.startswith(prefix):
            return l[len(prefix):]
    return ""


def desired(issue):
    """(status, column) the issue's state asks for; None where it asks nothing."""
    labels = {l["name"] for l in issue["labels"]}
    if issue["state"].upper() == "CLOSED":
        if "feedback-closed" in labels:
            return ("feedback-closed", None)
        if labels & {"wontfix", "declined"}:
            return ("declined", None)
        if (issue.get("stateReason") or "").upper() == "DUPLICATE" or "duplicate" in labels:
            return ("duplicate", None)
        if (issue.get("stateReason") or "").upper() == "NOT_PLANNED":
            # Closed without being done, by a session that checked it (no
            # longer applies, a duplicate, an idea with nothing to do yet).
            return ("closed", None)
        if "working-as-intended" in labels:
            return ("working-as-intended", None)
        # Closed is finished: by Beacon (auto-fixed) or by a session that
        # closed it with a comment naming the commit.
        return ("auto-fixed", "done")
    for label, result in OPEN_LABELS:
        if label in labels:
            return result
    return (None, None)


def rank(status):
    return RANK.get(status, 2)


def sections(body):
    """The fixed headings Beacon renders into an issue, as {heading: text}."""
    parts = re.split(r"(?m)^#{2,3}\s+(.+?)\s*$", body or "")
    return {parts[i].strip(): parts[i + 1].strip() for i in range(1, len(parts) - 1, 2)}


def metadata(body):
    m = re.search(r"<!--\s*beacon-metadata\s*(.*?)-->", body or "", re.S)
    if not m:
        return {}
    try:
        data = json.loads(m.group(1))
        return data if isinstance(data, dict) else {}
    except ValueError:
        return {}


def reporter_of(issue, meta):
    """Who sent it. A report from a website or app comes through the relay, so
    the issue's author is the relay; the person is named in the issue's first
    lines ("Reported by **Name** ... Reach them at **address**")."""
    body = issue.get("body") or ""
    named = re.search(r"Reported by \*\*(.+?)\*\*", body)
    reach = re.search(r"Reach them at \*\*(.+?)\*\*", body)
    name = named.group(1).strip() if named else ""
    email = reach.group(1).strip() if reach else ""
    if name and email:
        return "%s <%s>" % (name, email)
    if name:
        return name
    login = (issue.get("author") or {}).get("login", "")
    if login.startswith("app/") or login.endswith("[bot]"):
        return "Anonymous (%s)" % (meta.get("platform") or "relay")
    return login


def attachments_of(sec):
    """The links under "What they attached": - [`name`](url) (size)."""
    out = []
    for line in (sec or "").splitlines():
        m = re.match(r"\s*[-*]\s*\[`?(.+?)`?\]\((\S+?)\)\s*(?:\((.+?)\))?\s*$", line)
        if m:
            out.append({"name": m.group(1), "url": m.group(2), "size": m.group(3) or ""})
    return out


def table_value(body, key):
    m = re.search(r"(?m)^\|\s*%s\s*\|\s*`?(.*?)`?\s*\|\s*$" % re.escape(key), body or "")
    return m.group(1).strip() if m else ""


def words_of(kind, sec, body):
    """The reporter's words, from the headings Beacon's issue rendering writes."""
    first = lambda *names: next((sec[n] for n in names if sec.get(n)), "")
    why = next((v for k, v in sec.items() if k.startswith("Why")), "")
    if kind == "bug" and ("What actually happened" in sec or "What they expected" in sec):
        return {
            "kind": "bug",
            "expected": sec.get("What they expected", ""),
            "whatHappened": sec.get("What actually happened", ""),
            "steps": [s for s in (re.sub(r"^\s*(?:\d+[.)]|[-*])\s*", "", x).strip()
                                  for x in sec.get("Steps to see it", "").splitlines()) if s],
            "reproducibility": sec.get("Does it happen again?", "").strip("* "),
        }
    if kind == "feature-request" and "What they want to be able to do" in sec:
        return {"kind": kind, "whatIWant": sec["What they want to be able to do"], "why": why,
                "idea": sec.get("Their idea", "")}
    if kind == "change-request" and "What they would like changed" in sec:
        return {"kind": kind, "whatToChange": sec["What they would like changed"],
                "instead": sec.get("What they would like instead", ""), "why": why}
    if kind == "feedback" and "What they said" in sec:
        return {"kind": kind, "message": sec["What they said"]}
    # An issue written by hand, not rendered by Beacon: its whole text.
    return {"kind": kind, "message": body}


def new_document(app, issue, status, column):
    repo = app["repository"]
    labels = [l["name"] for l in issue["labels"]]
    meta = metadata(issue.get("body"))
    kind = label_value(labels, "type:") or "feedback"
    body = (issue.get("body") or "")
    body = re.sub(r"<!--\s*beacon-metadata.*?-->", "", body, flags=re.S).strip()[:BODY_LIMIT]
    # The relay quotes the reporter's words in the issue; the board shows them plain.
    sec = {k: re.sub(r"(?m)^>\s?", "", v).strip() for k, v in sections(body).items()}
    words = words_of(kind, sec, body)
    ctx = meta.get("context") if isinstance(meta.get("context"), dict) else {}
    reference = meta.get("reference") if isinstance(meta.get("reference"), str) else \
        "GH-%s-%d" % (repo.split("/")[1], issue["number"])
    context = {k: str(ctx.get(k, "")) for k in ("version", "build", "commit", "os", "device")}
    page = table_value(body, "Page")
    if page:
        context["page"] = page
    part = re.search(r"\*\*Part of the site\*\*:\s*(.+)", body)
    if part:
        context["partOfSite"] = part.group(1).strip()
    doc = {
        "app": {"id": app["id"], "name": app.get("name", app["id"]),
                "platform": app.get("platform", ""), "repository": repo},
        "reference": reference, "kind": kind, "filedAt": issue["createdAt"],
        "status": status or "filed", "title": issue["title"],
        "reporter": reporter_of(issue, meta),
        "impact": label_value(labels, "impact:"), "area": label_value(labels, "area:"),
        "body": words, "context": context,
        "attachmentCount": 0, "issueNumber": issue["number"], "issueURL": issue["url"],
        "ticket": "%s-%d" % (app_prefix(app), issue["number"]),
        "source": "beacon-sheet",
    }
    links = attachments_of(sec.get("What they attached", ""))
    if links:
        doc["attachmentLinks"] = links
    if column:
        doc["column"] = column
    return doc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", required=True)
    ap.add_argument("--apps", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--versions")
    ap.add_argument("--default-version", type=int, default=1,
                    help="version assumed for a document not in --versions")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    reports = load_dir(a.reports)
    apps = [dict(id=i, **d) for i, d in load_dir(a.apps).items()]
    versions = json.load(open(a.versions)) if a.versions else {}
    base = a.default_version
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    by_issue = {}
    for ref, d in reports.items():
        if d.get("issueNumber") and d.get("app", {}).get("id"):
            by_issue[(d["app"]["id"], d["issueNumber"])] = (ref, d)

    writes, counts = [], {"create": 0, "update": 0, "same": 0, "untriaged": 0, "held": 0, "linked": 0}
    for app in apps:
        if app.get("tracker", "github") != "github" or not app.get("repository"):
            continue
        work = gh_work(app["repository"])
        for issue in gh_issues(app["repository"]):
            # A test submission, labelled test: never on the board.
            if any(l["name"] == "test" for l in issue["labels"]):
                continue
            status, column = desired(issue)
            found = by_issue.get((app["id"], issue["number"]))
            if not found:
                doc = new_document(app, issue, status, column)
                if column:
                    doc["columnAt"] = now
                writes.append({"op": "set", "collection": "reports", "doc_id": doc["reference"], "data": doc})
                counts["create"] += 1
                continue
            ref, d = found
            cur = d.get("status")
            # A branch or pull request moves the report, whoever decided on it.
            ticket = "%s-%d" % (app_prefix(app), issue["number"])
            # The number a person says out loud, written once so every reader
            # of the board (the worker, the pickup) uses the same one.
            extra = {"ticket": ticket} if d.get("ticket") != ticket else {}
            linked = link_change(d, issue, work.get(issue["number"]))
            linked.update(extra) if linked else None
            if linked:
                if "status" in linked or "column" in linked:
                    linked["columnAt"] = now
                writes.append({"op": "update", "collection": "reports", "doc_id": ref, "data": linked,
                               "if_version": int(versions.get(ref, base))})
                counts["linked"] += 1
                continue
            # Held: the owner decided on it, the pickup is working it, or the
            # owner set its status and flags by hand (editedAt).
            if d.get("approval") or d.get("editedAt") or cur in HELD:
                counts["held"] += 1
                if extra:
                    writes.append({"op": "update", "collection": "reports", "doc_id": ref, "data": extra,
                                   "if_version": int(versions.get(ref, base))})
                continue
            if status is None and column is None:
                counts["untriaged"] += 1
                if extra:
                    writes.append({"op": "update", "collection": "reports", "doc_id": ref, "data": extra,
                                   "if_version": int(versions.get(ref, base))})
                continue
            change = {}
            cur_column = d.get("column")
            if status and status != cur and rank(status) > rank(cur):
                # The labels say more than the board does: take the status
                # and the column that goes with it.
                change["status"] = status
                if column and column != cur_column:
                    change["column"] = column
            elif status and status == cur and column and not cur_column:
                change["column"] = column
            elif status is None and column == "done" and cur_column not in ("done", "deployed"):
                change["column"] = column
            if not change:
                counts["same"] += 1
                if extra:
                    writes.append({"op": "update", "collection": "reports", "doc_id": ref, "data": extra,
                                   "if_version": int(versions.get(ref, base))})
                continue
            change.update(extra)
            change["columnAt"] = now
            writes.append({"op": "update", "collection": "reports", "doc_id": ref, "data": change,
                           "if_version": int(versions.get(ref, base))})
            counts["update"] += 1

    summary = dict(counts, writes=len(writes), batches=(len(writes) + BATCH - 1) // BATCH)
    print(json.dumps(summary))
    if a.dry_run:
        return 0
    os.makedirs(a.out, exist_ok=True)
    for old in glob.glob(os.path.join(a.out, "batch-*.json")):
        os.remove(old)
    for n in range(0, len(writes), BATCH):
        with open(os.path.join(a.out, "batch-%02d.json" % (n // BATCH + 1)), "w") as fh:
            json.dump({"writes": writes[n:n + BATCH]}, fh, separators=(",", ":"))
    with open(os.path.join(a.out, "summary.json"), "w") as fh:
        json.dump(summary, fh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
