import { createClient } from "npm:@supabase/supabase-js@2";

const VERSION = "clarifo_nexus_adapter_v2";
const MAX_BODY_BYTES = 1_000_000;

type PacketInput = {
  packet_key: string;
  ticker: string;
  company_name: string;
  instrument_type: string;
  research_lane: string;
  packet_json: Record<string, unknown>;
  market?: string | null;
  cik?: string | null;
  retrieved_at?: string | null;
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function secretMatches(provided: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const left = new Uint8Array(a);
  const right = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}

function validatePacket(value: unknown): value is PacketInput {
  if (!isRecord(value)) return false;
  const requiredText = [
    "packet_key",
    "ticker",
    "company_name",
    "instrument_type",
    "research_lane",
  ] as const;

  for (const key of requiredText) {
    if (typeof value[key] !== "string" || value[key].trim().length === 0) return false;
  }
  if ((value.packet_key as string).length > 240) return false;
  if (!/^[A-Z0-9.]{1,15}$/.test(value.ticker as string)) return false;
  if (typeof value.packet_json !== "object" || value.packet_json === null ||
      Array.isArray(value.packet_json)) return false;

  for (const key of ["market", "cik", "retrieved_at"] as const) {
    if (value[key] !== undefined && value[key] !== null && typeof value[key] !== "string") {
      return false;
    }
  }
  if (typeof value.market === "string" && value.market.length > 80) return false;
  if (typeof value.cik === "string" && value.cik.length > 20) return false;
  if (typeof value.retrieved_at === "string" &&
      Number.isNaN(Date.parse(value.retrieved_at))) return false;
  return true;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  // verify_jwt must remain enabled at deployment. This additional server-side
  // secret limits this endpoint to the separately provisioned intake caller.
  const sharedSecret = Deno.env.get("CLARIFO_INGEST_SHARED_SECRET");
  if (!sharedSecret || !await secretMatches(
    request.headers.get("x-nexus-clarifo-ingest-key") ?? "",
    sharedSecret,
  )) {
    return json(401, { error: "unauthorized" });
  }

  if (Deno.env.get("CLARIFO_INGEST_ENABLED") !== "true") {
    return json(503, { error: "ingestion_disabled" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json(503, { error: "server_configuration_incomplete" });
  }

  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > MAX_BODY_BYTES) {
    return json(413, { error: "payload_too_large" });
  }

  let raw: string;
  try {
    raw = await request.text();
  } catch {
    return json(400, { error: "invalid_body" });
  }
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
    return json(413, { error: "payload_too_large" });
  }

  let candidate: unknown;
  try {
    candidate = JSON.parse(raw);
  } catch {
    return json(400, { error: "invalid_json" });
  }
  if (!validatePacket(candidate)) {
    return json(422, { error: "invalid_packet" });
  }

  const packet = candidate;
  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  }).schema("nexus");

  const { data: appendRows, error: appendError } = await db.rpc(
    "clarifo_packet_append_v1",
    {
      p_packet_key: packet.packet_key,
      p_ticker: packet.ticker,
      p_company_name: packet.company_name,
      p_instrument_type: packet.instrument_type,
      p_research_lane: packet.research_lane,
      p_packet_json: packet.packet_json,
      p_adapter_version: VERSION,
      p_market: packet.market ?? null,
      p_cik: packet.cik ?? null,
      p_retrieved_at: packet.retrieved_at ?? null,
    },
  );

  if (appendError) {
    // Do not log the packet, secret, or database error details.
    return json(502, { error: "append_unavailable" });
  }

  const append = Array.isArray(appendRows) ? appendRows[0] : null;
  const packetId = append?.clarifo_ingestion_packet_id;
  if (typeof packetId !== "string" || !["inserted", "duplicate"].includes(append?.outcome)) {
    return json(502, { error: "append_receipt_invalid" });
  }

  if (append.outcome === "duplicate") {
    return json(409, { error: "packet_key_already_exists", packet_id: packetId });
  }

  const { data: readback, error: readbackError } = await db
    .from("clarifo_ingestion_packets")
    .select(
      "clarifo_ingestion_packet_id,packet_key,ticker,evidence_status,review_status,thesis_promotion_allowed,trade_action_allowed",
    )
    .eq("clarifo_ingestion_packet_id", packetId)
    .maybeSingle();

  if (
    readbackError || !readback ||
    readback.packet_key !== packet.packet_key ||
    readback.ticker !== packet.ticker ||
    readback.evidence_status !== "evidence_open" ||
    readback.review_status !== "pending_human_review" ||
    readback.thesis_promotion_allowed !== false ||
    readback.trade_action_allowed !== false
  ) {
    return json(502, { error: "readback_verification_failed", packet_id: packetId });
  }

  return json(201, {
    outcome: "inserted",
    packet_id: packetId,
    packet_key: packet.packet_key,
    ticker: packet.ticker,
    evidence_status: readback.evidence_status,
    review_status: readback.review_status,
    thesis_promotion_allowed: false,
    trade_action_allowed: false,
  });
});
