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
`approval`) or the pickup is working (approved, triaging), is left alone.
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
HELD = {"approved", "triaging", "declined"}
BATCH = 50
BODY_LIMIT = 6000


def gh_issues(repo):
    out = subprocess.run(
        ["gh", "issue", "list", "--repo", repo, "--label", "beacon", "--state", "all",
         "--limit", "2000", "--json", "number,title,state,stateReason,labels,body,url,createdAt,author"],
        check=True, capture_output=True, text=True).stdout
    return json.loads(out)


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


def new_document(app, issue, status, column):
    repo = app["repository"]
    labels = [l["name"] for l in issue["labels"]]
    meta = metadata(issue.get("body"))
    kind = label_value(labels, "type:") or "feedback"
    body = (issue.get("body") or "")
    body = re.sub(r"<!--\s*beacon-metadata.*?-->", "", body, flags=re.S).strip()[:BODY_LIMIT]
    # The relay quotes the reporter's words in the issue; the board shows them plain.
    sec = {k: re.sub(r"(?m)^>\s?", "", v).strip() for k, v in sections(body).items()}
    if kind == "bug" and ("What actually happened" in sec or "What they expected" in sec):
        words = {
            "kind": "bug",
            "expected": sec.get("What they expected", ""),
            "whatHappened": sec.get("What actually happened", ""),
            "steps": [s for s in (re.sub(r"^\s*(?:\d+[.)]|[-*])\s*", "", x).strip()
                                  for x in sec.get("Steps to see it", "").splitlines()) if s],
            "reproducibility": "",
        }
    else:
        words = {"kind": kind, "message": body}
    ctx = meta.get("context") if isinstance(meta.get("context"), dict) else {}
    reference = meta.get("reference") if isinstance(meta.get("reference"), str) else \
        "GH-%s-%d" % (repo.split("/")[1], issue["number"])
    doc = {
        "app": {"id": app["id"], "name": app.get("name", app["id"]),
                "platform": app.get("platform", ""), "repository": repo},
        "reference": reference, "kind": kind, "filedAt": issue["createdAt"],
        "status": status or "filed", "title": issue["title"],
        "reporter": reporter_of(issue, meta),
        "impact": label_value(labels, "impact:"), "area": label_value(labels, "area:"),
        "body": words,
        "context": {k: str(ctx.get(k, "")) for k in ("version", "build", "commit", "os", "device")},
        "attachmentCount": 0, "issueNumber": issue["number"], "issueURL": issue["url"],
        "source": "beacon-sheet",
    }
    if column:
        doc["column"] = column
    return doc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", required=True)
    ap.add_argument("--apps", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--versions")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    reports = load_dir(a.reports)
    apps = [dict(id=i, **d) for i, d in load_dir(a.apps).items()]
    versions = json.load(open(a.versions)) if a.versions else {}
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    by_issue = {}
    for ref, d in reports.items():
        if d.get("issueNumber") and d.get("app", {}).get("id"):
            by_issue[(d["app"]["id"], d["issueNumber"])] = (ref, d)

    writes, counts = [], {"create": 0, "update": 0, "same": 0, "untriaged": 0, "held": 0}
    for app in apps:
        if app.get("tracker", "github") != "github" or not app.get("repository"):
            continue
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
            if d.get("approval") or cur in HELD:
                counts["held"] += 1
                continue
            if status is None and column is None:
                counts["untriaged"] += 1
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
                continue
            change["columnAt"] = now
            writes.append({"op": "update", "collection": "reports", "doc_id": ref, "data": change,
                           "if_version": int(versions.get(ref, 1))})
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
