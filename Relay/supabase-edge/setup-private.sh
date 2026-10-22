#!/bin/bash
# Sets up private delivery once, on the owner's Mac (see docs/setup-private.md).
#
#   Relay/supabase-edge/setup-private.sh <project-ref> <name> [<bundle-id> ...]
#
# <project-ref> is the Supabase project the relay runs in. <name> labels the
# keypair and the token, such as your app's name. List bundle identifiers to
# let only those apps store messages; list none to allow any app with the token.
#
# It needs the Supabase CLI signed in, with permission to set secrets and
# deploy functions. It never reads the project's keys. It:
#   1. makes the keypair: the private key goes into this Mac's keychain and is
#      never printed. When a key for <name> already exists it is kept and
#      reused, because a new one would make everything stored unreadable,
#   2. makes a random token, keeps it in this Mac's keychain (account <name>,
#      service beacon-private-app-token) and gives it to the function,
#   3. deploys the `beacon-private` function, which creates the private bucket
#      `beacon-private` on its first write,
#   4. prints the public key and the endpoint for the app's PrivateDelivery.
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

# 1. The keypair, or the one this Mac already holds for <name>.
TOOL=(swift run --package-path "$ROOT" -c release beacon-private)
PUBLIC_KEY="$("${TOOL[@]}" pubkey "$NAME" 2>/dev/null || "${TOOL[@]}" keygen "$NAME")"

# 2. The token.
TOKEN="$(openssl rand -hex 32)"
security add-generic-password -a "$NAME" -s beacon-private-app-token -w "$TOKEN" -U
supabase secrets set --project-ref "$PROJECT_REF" "BEACON_PRIVATE_TOKEN=$TOKEN" "PRIVATE_APPS=$APPS" >/dev/null
unset TOKEN

# 3. The function.
supabase functions deploy beacon-private --project-ref "$PROJECT_REF" --no-verify-jwt --workdir "$HERE"

# 4. What the app needs.
echo
echo "Endpoint:   https://$PROJECT_REF.supabase.co/functions/v1/beacon-private"
echo "Public key: $PUBLIC_KEY"
echo "Token:      in this Mac's keychain (account $NAME, service beacon-private-app-token)"
