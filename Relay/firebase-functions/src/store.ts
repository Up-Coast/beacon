// The private store on a Cloud Storage bucket: one object per sealed message, written
// create-only so a second upload of the same id never replaces the first.

import type { StoreResult } from "../../supabase-edge/supabase/functions/beacon-private/private.ts";

/** Where sealed messages sit in the bucket, ahead of `<bundle id>/<uuid>.bin`. */
export const OBJECT_PREFIX = "beacon-private/";

/** The part of a Cloud Storage bucket the store uses. */
export interface ObjectBucket {
  file(name: string): {
    save(data: Buffer, options: {
      contentType: string;
      resumable: boolean;
      preconditionOpts: { ifGenerationMatch: number };
    }): Promise<void>;
  };
}

/** `ifGenerationMatch: 0` succeeds only when no live object has the name; Storage answers 412 otherwise. */
export function storeInCloudStorage(bucket: ObjectBucket) {
  return async (path: string, bytes: Uint8Array): Promise<StoreResult> => {
    try {
      await bucket.file(`${OBJECT_PREFIX}${path}`).save(Buffer.from(bytes), {
        contentType: "application/octet-stream",
        resumable: false,
        preconditionOpts: { ifGenerationMatch: 0 },
      });
      return "stored";
    } catch (error) {
      if ((error as { code?: number }).code === 412) return "exists";
      throw error;
    }
  };
}
