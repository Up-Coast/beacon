#!/usr/bin/env bash
# Create Beacon's label vocabulary in a repository.
#
# Run once per repository that receives reports. Safe to re-run: existing
# labels are updated rather than duplicated. Needs the `gh` CLI, signed in
# with access to the repo.
#
#   ./Scripts/beacon-labels.sh your-org/your-app

set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "usage: beacon-labels.sh <owner/repo>" >&2
  exit 2
fi

label() {
  gh label create "$1" --repo "$REPO" --color "$2" --description "$3" --force >/dev/null
  echo "  $1"
}

echo "Creating Beacon labels on $REPO"

label "beacon"                 "5B21B6" "Filed from inside the app with Beacon"

label "type:bug"              "D73A4A" "Something is broken"
label "type:feature-request"  "0E8A16" "Something is missing"
label "type:feedback"         "C5DEF5" "General feedback"

# Impact — the reporter's own answer about what this costs them.
label "impact:blocked"        "B60205" "They can't do what they came to do"
label "impact:slowed"         "D93F0B" "There's a workaround, but it costs them time"
label "impact:irritating"     "FBCA04" "It bothers them, but they can keep working"
label "impact:noticed"        "FEF2C0" "They noticed it; it doesn't really affect them"

# Severity — set during triage, never by the app.
label "severity:critical"     "B60205" "Data loss, security, or unusable for anyone who hits it"
label "severity:high"         "D93F0B" "A main path is broken with no workaround"
label "severity:medium"       "FBCA04" "Broken with a workaround, or a secondary path"
label "severity:low"          "C2E0C6" "Cosmetic, rare, or only under unusual settings"

# Triage outcomes.
label "triaged"               "BFDADC" "Triage has been through it"
label "needs-info"            "D4C5F9" "Waiting on an answer from the reporter"
label "cannot-reproduce"      "E4E669" "Couldn't be made to happen again — nobody may work on it"
label "expectation-mismatch"  "1D76DB" "The app did what it should; the product didn't explain itself"
label "working-as-intended"   "BFD4F2" "Behaving as designed"
label "auto-fixed"            "0E8A16" "Fixed, verified by running the app, and merged"
label "needs-human"           "5319E7" "Past what may be done unattended"

echo
echo "Done. Area labels (area:<id>) are created as reports arrive —"
echo "their ids come from BeaconIndex.json."
