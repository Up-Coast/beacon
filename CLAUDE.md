# Working on Beacon

Follow the Up Coast engineering standards, including "Testing leaves no mess in anyone's inbox" in `rules/06-testing.md`.

- Testing Beacon files real GitHub issues and can trigger workflow runs, and each one can email the owner. Close or delete test issues when a test pass ends.
- `.github/workflows/beacon-triage.yml` is a template for app repositories. It is switched off in this repository because the Claude GitHub App is not installed here. Do not switch it back on unless the owner asks.
- A workflow that fails on every run is a defect: fix it, or switch it off with the owner's agreement.
