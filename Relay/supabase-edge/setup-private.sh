#!/bin/bash
# Sets up private delivery once, on the owner's Mac (see docs/setup-private.md).
#
#   Relay/supabase-edge/setup-private.sh <project-ref> <name> [<bundle-id> ...]
#
# <project-ref> is the Supabase project the relay runs in. <name> labels the
# keypair and the token, such as your app's name. List bundle identifiers to
# let only those apps store messages; list none to allow any app with the token.
#
# It needs the Supabase CLI signed in. It:
#   1. makes the keypair: the private key goes into this Mac's keychain and is
#      never printed (refused when one exists for <name>, so nothing is replaced),
#   2. creates the private bucket `beacon-private`: 64 KiB per object,
#      application/octet-stream only, and no policies, so only the function reaches it,
#   3. makes a random token, keeps it in this Mac's keychain (account <name>,
#      service beacon-private-app-token) and gives it to the function,
#   4. deploys the `beacon-private` function,
#   5. prints the public key and the endpoint for the app's PrivateDelivery.
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "usage: $0 <project-ref> <name> [<bundle-id> ...]" >&2
    exit 2
fi
PROJECT_REF="$1"
NAME="$2"
shift 2
APPS="$(IFS=,; echo "$*")"
HERE="$(dirname "$0")"
ROOT="$HERE/../.."

# 1. The keypair.
PUBLIC_KEY="$(swift run --package-path "$ROOT" -c release beacon-private keygen "$NAME")"

# 2. The bucket. An existing bucket answers 400 or 409, which is fine.
ACCESS="$(supabase projects api-keys --project-ref "$PROJECT_REF" -o json \
    | python3 -c 'import sys,json; print([k["api_key"] for k in json.load(sys.stdin) if k["name"]=="service_role"][0])')"
STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST "https://$PROJECT_REF.supabase.co/storage/v1/bucket" \
    -H "Authorization: Bearer $ACCESS" -H "Content-Type: application/json" \
    -d '{"id":"beacon-private","name":"beacon-private","public":false,"file_size_limit":65536,"allowed_mime_types":["application/octet-stream"]}')"
unset ACCESS
if [[ "$STATUS" != "200" && "$STATUS" != "400" && "$STATUS" != "409" ]]; then
    echo "Creating the bucket answered $STATUS." >&2
    exit 1
fi

# 3. The token.
TOKEN="$(openssl rand -hex 32)"
security add-generic-password -a "$NAME" -s beacon-private-app-token -w "$TOKEN" -U
supabase secrets set --project-ref "$PROJECT_REF" "BEACON_PRIVATE_TOKEN=$TOKEN" "PRIVATE_APPS=$APPS" >/dev/null
unset TOKEN

# 4. The function.
supabase functions deploy beacon-private --project-ref "$PROJECT_REF" --no-verify-jwt --workdir "$HERE"

# 5. What the app needs.
echo
echo "Endpoint:   https://$PROJECT_REF.supabase.co/functions/v1/beacon-private"
echo "Public key: $PUBLIC_KEY"
echo "Token:      in this Mac's keychain (account $NAME, service beacon-private-app-token)"
