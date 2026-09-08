#!/usr/bin/env bash
# Put Beacon's GitHub-side pieces into an app's repository.
#
#   ./Scripts/beacon-adopt-github.sh /path/to/app-checkout owner/name
#
# Copies the triage policy, the triage skill, the two workflows and the
# issue templates into the app's repository (replacing Beacon-owned files,
# leaving anything else alone), and creates the label vocabulary on GitHub.
# Safe to re-run. Needs the `gh` CLI signed in with access to the repo.
#
# It does NOT register the OAuth app, install the Claude GitHub App, or add
# secrets — those are yours, and docs/setup-github.md walks through them.

set -euo pipefail

TARGET="${1:-}"
REPO="${2:-}"
if [ -z "$TARGET" ] || [ -z "$REPO" ]; then
  echo "usage: beacon-adopt-github.sh <app-checkout-dir> <owner/repo>" >&2
  exit 2
fi
if [ ! -d "$TARGET/.git" ]; then
  echo "$TARGET is not a git checkout" >&2
  exit 2
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"

copy() {  # copy <relative path> — file or directory
  mkdir -p "$TARGET/$(dirname "$1")"
  rm -rf "${TARGET:?}/$1"
  cp -R "$HERE/$1" "$TARGET/$1"
  echo "  $1"
}

echo "Copying into $TARGET"
copy Triage/TRIAGE.md
copy Triage/PICKUP.md
copy .claude/skills/beacon-triage
copy .github/workflows/beacon-triage.yml
copy .github/workflows/beacon-reproduce.yml
copy .github/ISSUE_TEMPLATE/bug.yml
copy .github/ISSUE_TEMPLATE/feature.yml
copy .github/ISSUE_TEMPLATE/config.yml
mkdir -p "$TARGET/Triage/seeds"

echo "Labels on $REPO"
"$HERE/Scripts/beacon-labels.sh" "$REPO"

cat <<MSG

Done. Commit what was copied. Still yours to do, once (docs/setup-github.md):
  1. Register a GitHub OAuth App with Device Flow enabled; put its Client ID in the app.
  2. Install the Claude GitHub App on $REPO and add the CLAUDE_CODE_OAUTH_TOKEN secret,
     if you want triage to run on GitHub's schedule rather than on your own machine.
  3. Point .github/workflows/beacon-reproduce.yml at your UI test scheme.
MSG
