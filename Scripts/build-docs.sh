#!/bin/sh
# Build the documentation site.
#
# MkDocs will not take the repository root as its docs_dir, so this stages the pages into
# .docs-build with their paths unchanged, then builds with --strict: a broken internal link
# fails the build.
#
# Usage:  Scripts/build-docs.sh          build into site/
#         Scripts/build-docs.sh serve    build and serve locally on :8000
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

staging=.docs-build
rm -rf "$staging"
mkdir -p "$staging"

for path in README.md CONTRIBUTING.md docs internal Triage/TRIAGE.md Triage/PICKUP.md Inbox/README.md Examples/BeaconExample/README.md; do
    [ -e "$path" ] || { echo "build-docs: missing $path" >&2; exit 1; }
    mkdir -p "$staging/$(dirname "$path")"
    cp -R "$path" "$staging/$(dirname "$path")/"
done

# LICENSE has no extension, so the site gets a Markdown copy of it.
{ printf '# Licence\n\n```text\n'; cat LICENSE; printf '```\n'; } > "$staging/LICENSE.md"

if [ "${1:-build}" = "serve" ]; then
    exec mkdocs serve
fi
mkdocs build --strict
echo "built: $root/site"
