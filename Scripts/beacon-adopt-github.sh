#!/usr/bin/env bash
# Put Beacon's GitHub-side pieces into an app's repository.
#
#   ./Scripts/beacon-adopt-github.sh /path/to/app-checkout owner/name [--with-actions]
#
# Copies the triage policy, the triage skill and the issue templates into
# the app's repository (replacing Beacon-owned files, leaving anything
# else alone), and creates the label vocabulary on GitHub. Safe to re-run.
# Needs the `gh` CLI signed in with access to the repo.
#
# The pickup runs on your Mac unless you ask otherwise, so the GitHub
# Actions workflows are NOT copied by default. Pass --with-actions to copy
# them, and know what they cost first: a private repository on a Free plan
# gets 2,000 Actions minutes a month, a macOS runner spends them ten times
# faster than Linux, and one iOS build job can eat a month. Public
# repositories are free.
#
# It does NOT register the OAuth app, install the Claude GitHub App, or add
# secrets — those are yours, and docs/setup-github.md walks through them.

set -euo pipefail

TARGET="${1:-}"
REPO="${2:-}"
WITH_ACTIONS=0
[ "${3:-}" = "--with-actions" ] && WITH_ACTIONS=1
if [ -z "$TARGET" ] || [ -z "$REPO" ]; then
  echo "usage: beacon-adopt-github.sh <app-checkout-dir> <owner/repo> [--with-actions]" >&2
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
if [ "$WITH_ACTIONS" = 1 ]; then
  copy .github/workflows/beacon-triage.yml
  copy .github/workflows/beacon-reproduce.yml
fi
copy .github/ISSUE_TEMPLATE/bug.yml
copy .github/ISSUE_TEMPLATE/feature.yml
copy .github/ISSUE_TEMPLATE/config.yml
mkdir -p "$TARGET/Triage/seeds"

echo "Labels on $REPO"
"$HERE/Scripts/beacon-labels.sh" "$REPO"

cat <<MSG

Done. Commit what was copied. Still yours to do, once (docs/setup-github.md):
  1. Register a GitHub OAuth App with Device Flow enabled; put its Client ID in the app.
  2. Set the pickup going: Triage/PICKUP.md as a scheduled task on your Mac.
MSG
if [ "$WITH_ACTIONS" = 1 ]; then
  cat <<MSG
  3. The Actions workflows were copied because you asked for them. They need the Claude
     GitHub App on $REPO and either CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY in its
     secrets; until then each scheduled run stops at its first job and finishes green.
     Point .github/workflows/beacon-reproduce.yml at your UI test scheme. Watch the cost:
     a private repository on a Free plan gets 2,000 minutes a month, and macOS runners
     spend them ten times faster than Linux.
MSG
fi
