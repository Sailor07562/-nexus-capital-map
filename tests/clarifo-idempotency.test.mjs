import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";

const VERSION = "clarifo_nexus_adapter_v2";
function jsonbText(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(jsonbText).join(", ")}]`;
  const keys = Object.keys(value).sort((a, b) => a.length - b.length || (a < b ? -1 : a > b ? 1 : 0));
  return `{${keys.map((key) => `${JSON.stringify(key)}: ${jsonbText(value[key])}`).join(", ")}}`;
}
function hash(packet) {
  return createHash("sha256").update(jsonbText({
    packet_key: packet.packet_key, adapter_version: VERSION, ticker: packet.ticker,
    company_name: packet.company_name, instrument_type: packet.instrument_type,
    research_lane: packet.research_lane, market: packet.market ?? null,
    cik: packet.cik ?? null, packet_json: packet.packet_json,
  })).digest("hex");
}

// Model the SQL unique constraint: insertion is atomic; the first immutable value wins.
function makeStore() {
  const rows = new Map();
  let next = 1;
  return {
    async append(packet) {
      const content_hash = hash(packet);
      const stored = rows.get(packet.packet_key);
      if (stored) return {
        outcome: stored.content_hash === content_hash ? "identical" : "conflict",
        id: stored.id,
        stored_content_hash: stored.content_hash,
      };
      const row = { ...structuredClone(packet), content_hash, id: String(next++) };
      rows.set(packet.packet_key, row);
      return { outcome: "inserted", id: row.id, stored_content_hash: content_hash };
    },
    get(key) { return rows.get(key); },
  };
}
const packet = () => ({
  packet_key: "AAPL:v1:abc", ticker: "AAPL", company_name: "Apple Inc.",
  instrument_type: "equity", research_lane: "fundamentals", market: "USA", cik: "320193",
  packet_json: { facts: [{ period: "FY2025", value: 100 }], packet_meta: { schema_version: "v1" } },
});

test("identical retry returns same ID only after full metadata and content hash match", async () => {
  const db = makeStore(), input = packet();
  const first = await db.append(input), retry = await db.append(structuredClone(input));
  assert.equal(first.outcome, "inserted");
  assert.equal(retry.outcome, "identical");
  assert.equal(retry.id, first.id);
  assert.equal(retry.stored_content_hash, hash(input));
});

test("changed packet JSON or any envelope metadata conflicts without overwrite", async () => {
  for (const mutate of [p => p.packet_json.facts[0].value++, p => p.company_name += " changed", p => p.market = "NASDAQ", p => p.research_lane = "other"]) {
    const db = makeStore(), original = packet();
    const first = await db.append(original), changed = structuredClone(original);
    mutate(changed);
    const result = await db.append(changed);
    assert.equal(result.outcome, "conflict");
    assert.deepEqual(db.get(original.packet_key), { ...original, content_hash: hash(original), id: first.id });
  }
});

test("concurrent same-key submissions converge on one immutable row", async () => {
  const db = makeStore(), input = packet();
  const results = await Promise.all(Array.from({ length: 20 }, () => db.append(structuredClone(input))));
  assert.equal(new Set(results.map(r => r.id)).size, 1);
  assert.equal(results.filter(r => r.outcome === "inserted").length, 1);
  assert.equal(results.filter(r => r.outcome === "identical").length, 19);
  assert.equal(db.get(input.packet_key).content_hash, hash(input));
});

test("uncertain first response is reconciled by same key before receipt; retry never rewrites", async () => {
  const db = makeStore(), input = packet();
  await db.append(input); // server committed; transport response is lost
  const reconciled = await db.append(structuredClone(input));
  assert.equal(reconciled.outcome, "identical");
  assert.equal(reconciled.id, "1");
  const changed = structuredClone(input); changed.packet_json.facts[0].value = 101;
  assert.equal((await db.append(changed)).outcome, "conflict");
});

test("SQL enforces server-side recomputed hash and row-lock reconciliation", async () => {
  const sql = await (await import("node:fs/promises")).readFile(new URL("../postgres/migrations/drafts/clarifo_packet_append_v1_draft.sql", import.meta.url), "utf8");
  assert.match(sql, /add column if not exists content_hash text/i);
  assert.match(sql, /v_expected_hash := encode\(extensions\.digest/);
  assert.match(sql, /if v_hash is distinct from v_expected_hash/);
  assert.match(sql, /v_packet_json is distinct from p_packet_json/);
  assert.match(sql, /v_company_name is distinct from p_company_name/);
  assert.match(sql, /v_market is distinct from p_market/);
  assert.match(sql, /for update;/i);
  assert.match(sql, /on conflict \(packet_key\) do nothing/i);
  assert.doesNotMatch(sql, /on conflict[^;]*do update/is);
});
