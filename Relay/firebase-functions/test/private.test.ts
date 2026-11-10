import { CRC32C, Storage } from "@google-cloud/storage";
import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { beforeAll, describe, expect, it } from "vitest";
import { privateHandler } from "../src/host.ts";
import { OBJECT_PREFIX, storeInCloudStorage } from "../src/store.ts";
import { APP, listen, post, secret } from "./support.ts";

// Run these under `firebase emulators:exec --only storage --project demo-relay`.
const PROJECT = "demo-relay";
const emulator = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const sealed = Buffer.alloc(64, 7).toString("base64");

describe.skipIf(!emulator)("the private store on the Storage emulator", () => {
  const bucket = getBucket();
  const id = crypto.randomUUID();
  let server: Awaited<ReturnType<typeof listen>>;

  function getBucket() {
    initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
    return getStorage().bucket();
  }

  beforeAll(async () => {
    server = await listen(() => privateHandler(secret(), storeInCloudStorage(bucket)));
    return () => server.close();
  });

  it("stores an upload as one object under the private prefix", async () => {
    expect((await post(server.url, { id, app: APP, ciphertext: sealed })).status).toBe(200);
    const [stored] = await bucket.file(`${OBJECT_PREFIX}${APP}/${id}.bin`).download();
    expect(stored.equals(Buffer.alloc(64, 7))).toBe(true);
  });

  it("refuses a wrong token", async () => {
    const response = await post(server.url, { id, app: APP, ciphertext: sealed }, { Authorization: "Bearer guess" });
    expect(response.status).toBe(401);
  });

  it("refuses an app's direct read and listing of the bucket", async () => {
    const base = `http://${emulator}/v0/b/${bucket.name}/o`;
    const name = encodeURIComponent(`${OBJECT_PREFIX}${APP}/${id}.bin`);
    expect((await fetch(`${base}/${name}?alt=media`)).status).toBe(403);
    expect((await fetch(`${base}?prefix=${OBJECT_PREFIX}`)).status).toBe(403);
    const written = await fetch(`${base}/${name}-x`, { method: "POST", body: "x" });
    expect(written.status).toBe(403);
  });
});

const checksum = (data: Buffer) => {
  const crc = new CRC32C();
  crc.update(data);
  return crc.toString();
};

// The Storage emulator does not enforce `ifGenerationMatch`, so the create-only write is
// proved against a stand-in for Storage that does what the real service documents: an
// upload with `ifGenerationMatch=0` for a name that already exists answers 412.
describe("the create-only write", () => {
  it("sends ifGenerationMatch=0, and a 412 answers 409 without replacing the first message", async () => {
    const held = new Map<string, string>();
    const preconditions: (string | null)[] = [];
    const storage = createServer(async (req, res) => {
      const chunks: Buffer[] = [];
      for await (const chunk of req) chunks.push(chunk as Buffer);
      const parts = Buffer.concat(chunks).toString("latin1").split("\r\n\r\n");
      const query = new URL(req.url!, "http://stand-in").searchParams;
      const name = query.get("name") ?? "";
      const data = Buffer.from((parts[2] ?? "").replace(/\r\n--.*$/s, ""), "latin1");
      const match = query.get("ifGenerationMatch");
      preconditions.push(match);
      const refused = match === "0" && held.has(name);
      if (!refused) held.set(name, "stored");
      res.statusCode = refused ? 412 : 200;
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify(refused ? { error: { code: 412, message: "conditionNotMet" } } : { name, generation: "1", crc32c: checksum(data) }));
    });
    await new Promise<void>((resolve) => storage.listen(0, "127.0.0.1", resolve));
    const endpoint = `http://127.0.0.1:${(storage.address() as AddressInfo).port}`;
    const bucket = new Storage({ apiEndpoint: endpoint, projectId: PROJECT }).bucket("stand-in");
    const server = await listen(() => privateHandler(secret(), storeInCloudStorage(bucket)));
    try {
      const send = () => post(server.url, { id: crypto.randomUUID().replace(/.$/, "0"), app: APP, ciphertext: sealed });
      const sameId = { id: "11111111-2222-3333-4444-555555555555", app: APP, ciphertext: sealed };
      expect((await post(server.url, sameId)).status).toBe(200);
      expect((await post(server.url, sameId)).status).toBe(409);
      expect((await send()).status).toBe(200);
      expect(preconditions).toEqual(["0", "0", "0"]);
      expect(held.size).toBe(2);
    } finally {
      await server.close();
      storage.close();
    }
  });
});
