#!/bin/sh
# Take the documentation's screenshots of the Beacon page.
#
# Copies Inbox/index.html into a temporary folder behind stand-in.js (made-up
# sample data, never published), serves it on 127.0.0.1, and has headless
# Google Chrome save each view as a PNG in docs/assets/.
#
# Usage:  Scripts/page-screenshots/take.sh
# Needs:  Google Chrome in /Applications, python3.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../.." && pwd)
out="$root/docs/assets"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
port=8737

work=$(mktemp -d)
trap 'kill "$server" 2>/dev/null || true; rm -rf "$work"' EXIT
cp "$here/stand-in.js" "$work/"
# The published page gets its charset and viewport from the artifact
# wrapper; the copy here needs them in front.
{
    printf '<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">\n'
    printf '<script src="stand-in.js"></script>\n'
    cat "$root/Inbox/index.html"
} > "$work/page.html"

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work" >/dev/null 2>&1 &
server=$!
sleep 1

# shoot <file> <width> <height> <scale> <query>
shoot() {
    profile=$(mktemp -d)
    rm -f "$out/$1"
    "$chrome" --headless=new --disable-gpu --hide-scrollbars --no-first-run \
        --user-data-dir="$profile" --force-prefers-reduced-motion \
        --blink-settings=preferredColorScheme=1 \
        --window-size="$2,$3" --force-device-scale-factor="$4" \
        --virtual-time-budget=4000 \
        --screenshot="$out/$1" "http://127.0.0.1:$port/page.html?$5" >/dev/null 2>&1 || true
    rm -rf "$profile"
    # Chrome can exit non-zero on teardown after writing the file, so the
    # file is the test.
    [ -s "$out/$1" ] || { echo "take: $1 was not written" >&2; exit 1; }
    echo "saved docs/assets/$1"
}

app_link="app=sample-notes&version=2.3.0&build=141&repo=example-org%2Fsample-notes&os=macOS&osVersion=26.1&device=Mac15%2C3"

shoot page-dashboard.png        1280 900  1 "shot=dashboard"
shoot page-decision.png         1280 1180 1 "shot=decision"
shoot page-apps.png             1280 900  1 "shot=apps"
shoot page-first-run.png        1280 560  1 "shot=first-run"
shoot page-form.png             1280 1400 1 "shot=form&$app_link"
# Headless Chrome will not make a window as narrow as a phone, so the phone
# shot is the page in a 390-pixel frame, centred, and cropped to the frame afterwards.
printf '<meta charset="utf-8"><style>html,body{margin:0}iframe{border:0;width:390px;height:844px;display:block;margin:0 auto}</style><iframe src="page.html?shot=form&%s"></iframe>\n' "$app_link" > "$work/phone.html"
rm -f "$out/page-form-phone.png"
profile=$(mktemp -d)
"$chrome" --headless=new --disable-gpu --hide-scrollbars --no-first-run --user-data-dir="$profile" \
    --blink-settings=preferredColorScheme=1 --window-size=800,844 --force-device-scale-factor=2 \
    --virtual-time-budget=4000 --screenshot="$out/page-form-phone.png" "http://127.0.0.1:$port/phone.html" >/dev/null 2>&1 || true
rm -rf "$profile"
[ -s "$out/page-form-phone.png" ] || { echo "take: page-form-phone.png was not written" >&2; exit 1; }
sips -c 1688 780 "$out/page-form-phone.png" >/dev/null
echo "saved docs/assets/page-form-phone.png"
