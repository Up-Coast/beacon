// The Firebase host for Beacon's relay and private store. The logic is the shared code
// in ../supabase-edge; this file only wires it to Firebase. The settings are one
// secret, RELAY_SECRETS, a JSON object (see the README).

import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { type HttpsOptions, onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { ANSWERS as RELAY_ANSWERS } from "../../supabase-edge/supabase/functions/beacon-relay/relay.ts";
import { ANSWERS as PRIVATE_ANSWERS } from "../../supabase-edge/supabase/functions/beacon-private/private.ts";
import { privateHandler, relayHandler, settingsFrom } from "./host.ts";
import { storeInCloudStorage } from "./store.ts";
import { serve } from "./web.ts";

/** Chosen once per project; the bucket and the database must be in the same one. */
const REGION = "us-central1";

const secrets = defineSecret("RELAY_SECRETS");
initializeApp();

const shared: HttpsOptions = {
  region: REGION, secrets: [secrets], memory: "1GiB", cpu: 1, timeoutSeconds: 120, concurrency: 4,
  invoker: "public", cors: false,
};

export const beaconRelay = onRequest(
  { ...shared, maxInstances: 3 },
  serve(() => relayHandler(secrets.value()), { error: RELAY_ANSWERS.unauthorized }),
);

/** The bucket is the project's default unless PRIVATE_BUCKET names another. */
export const beaconPrivate = onRequest(
  { ...shared, maxInstances: 2 },
  serve(() => {
    const secret = secrets.value();
    return privateHandler(secret, storeInCloudStorage(getStorage().bucket(settingsFrom(secret)("PRIVATE_BUCKET"))));
  }, { message: PRIVATE_ANSWERS.unauthorized }),
);
