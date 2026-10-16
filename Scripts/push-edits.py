#!/usr/bin/env python3
"""Push the owner's changes on the Beacon board to the GitHub issues.

The board is where the owner changes a report: its status, its flags, a move to
another column, a cancel. GitHub's page cannot hear the board, so this script
does it. It reads the board documents (saved with the ArtifactData tool's `list`
and `out_dir`), and for every report the owner has touched (`editedAt`) it makes
the issue say the same thing: the labels for the status and the flags, and open
or closed.

    python3 Scripts/push-edits.py --reports <dir> [--dry-run]

It is safe to run again: every step sets a state, it never toggles. It posts no
comments (the pickup comments when it acts on an approval or a cancel). It
never edits an issue the owner has not touched on the board.

Status and flags to labels:

  Inbox                     no status label
  Triaged                   triaged
  Backlog                   backlog
  To do                     todo
  In progress               in-progress
  Done                      auto-fixed, closed as completed
  Deployed                  auto-fixed and deployed, closed as completed
  Works as designed         working-as-intended, closed as completed
  Canceled                  wontfix, closed as not planned
  Duplicate                 duplicate, closed as a duplicate

  Needs your decision       needs-human
  Needs more info           needs-info
  Can't reproduce           cannot-reproduce
  Confusing to users        expectation-mismatch
  any other flag            flag:<the flag, lowercase, hyphens>
                            (Waiting for human is flag:waiting-for-human,
                            the worker's Blocked is flag:blocked)
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

STATUS_LABEL = {
    "new": [], "filed": [], "triaged": ["triaged"], "backlog": ["backlog"],
    "todo": ["todo"], "approved": ["todo"], "triaging": ["in-progress"],
    "auto-fixed": ["auto-fixed"], "deployed": ["auto-fixed", "deployed"],
    "working-as-intended": ["working-as-intended"], "declined": ["wontfix"],
    "closed": ["wontfix"], "duplicate": ["duplicate"], "feedback-closed": ["feedback-closed"],
    # Statuses the owner never sets by hand now; they keep their own label.
    "needs-human": ["triaged", "needs-human"], "needs-info": ["triaged", "needs-info"],
    "cannot-reproduce": ["triaged", "cannot-reproduce"],
    "expectation-mismatch": ["triaged", "expectation-mismatch"],
}
FLAG_LABEL = {
    "Needs your decision": "needs-human", "Needs more info": "needs-info",
    "Can't reproduce": "cannot-reproduce", "Confusing to users": "expectation-mismatch",
}
# Closing states: status -> gh close reason
CLOSES = {
    "auto-fixed": "completed", "deployed": "completed", "working-as-intended": "completed",
    "declined": "not planned", "closed": "not planned", "duplicate": "duplicate", "feedback-closed": "completed",
}
MANAGED = {l for ls in STATUS_LABEL.values() for l in ls} | set(FLAG_LABEL.values()) | {"deployed"}


def gh(*args, check=True):
    return subprocess.run(["gh", *args], check=check, capture_output=True, text=True).stdout


def flag_label(flag):
    if flag in FLAG_LABEL:
        return FLAG_LABEL[flag]
    return "flag:" + re.sub(r"[^a-z0-9]+", "-", flag.lower()).strip("-")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reports", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    done = {"checked": 0, "labelled": 0, "closed": 0, "reopened": 0, "skipped": 0}
    made = {}  # repo -> labels created this run
    for f in sorted(glob.glob(os.path.join(a.reports, "*.json"))):
        d = json.load(open(f))
        repo = (d.get("app") or {}).get("repository")
        number = d.get("issueNumber")
        if not d.get("editedAt") or not repo or not number or d.get("hidden"):
            continue
        done["checked"] += 1
        status = d.get("duplicateOf") and "duplicate" or d.get("status")
        if status not in STATUS_LABEL:
            done["skipped"] += 1
            continue
        want = set(STATUS_LABEL[status]) | {flag_label(x) for x in (d.get("flags") or [])}
        try:
            cur = json.loads(gh("issue", "view", str(number), "--repo", repo, "--json", "labels,state"))
        except subprocess.CalledProcessError:
            done["skipped"] += 1
            continue
        have = {l["name"] for l in cur["labels"]}
        add = sorted(want - have)
        # flag:* labels are the board's own flags, so a cleared flag loses its label.
        remove = sorted({l for l in have if l in MANAGED or l.startswith("flag:")} - want)
        if add or remove:
            if not a.dry_run:
                for label in add:
                    if label not in made.setdefault(repo, set()):
                        gh("label", "create", label, "--repo", repo, "--color", "ededed", check=False)
                        made[repo].add(label)
                args = ["issue", "edit", str(number), "--repo", repo]
                for label in add:
                    args += ["--add-label", label]
                for label in remove:
                    args += ["--remove-label", label]
                gh(*args)
            done["labelled"] += 1
        closing = CLOSES.get(status)
        is_open = cur["state"].upper() == "OPEN"
        if closing and is_open:
            if not a.dry_run:
                gh("issue", "close", str(number), "--repo", repo, "--reason", closing)
            done["closed"] += 1
        elif not closing and not is_open:
            if not a.dry_run:
                gh("issue", "reopen", str(number), "--repo", repo)
            done["reopened"] += 1
    print(json.dumps(done))
    return 0


if __name__ == "__main__":
    sys.exit(main())
