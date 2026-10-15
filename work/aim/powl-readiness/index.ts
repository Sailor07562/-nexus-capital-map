// Nexus A.I.M. sandbox-only POWL readiness endpoint.
// Requires Supabase JWT verification at the gateway AND a caller JWT with an
// approved role claim. The service key is used only for read-only queries.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const MISSION = "NEXUS-AIM-POWL-PILOT-20261015-001";
const respond = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

function decodeClaims(token: string): Record<string, unknown> | null {
  try {
    const segment = token.split(".")[1];
    if (!segment) return null;
    const b64 = segment.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "=")));
  } catch { return null; }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return respond({ error: "method_not_allowed" }, 405);
  const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/)?.[1];
  if (!token) return respond({ error: "unauthorized" }, 401);
  // Claim parsing is not signature verification: the Supabase gateway MUST
  // enforce verify_jwt=true before this function is reachable.
  const claims = decodeClaims(token);
  if (claims?.role !== "service_role") return respond({ error: "forbidden" }, 403);
  let payload: unknown;
  try { payload = await request.json(); }
  catch { return respond({ error: "invalid_json" }, 400); }
  if (!payload || typeof payload !== "object" || (payload as Record<string, unknown>).action !== "readiness") {
    return respond({ error: "unsupported_action" }, 400);
  }
  const base = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!base || !key) return respond({ error: "configuration_unavailable" }, 503);
  const headers = { apikey: key, authorization: `Bearer ${key}` };
  const read = (view: string, columns: string) =>
    fetch(`${base}/rest/v1/${view}?mission_id=eq.${MISSION}&select=${columns}`, {
      headers,
      signal: AbortSignal.timeout(7000),
    });
  try {
    const [mission, governance] = await Promise.all([
      read("v_mission_readiness_v1", "readiness,verified_evidence_count,open_risks,sent_receipts,acknowledged_receipts"),
      read("v_governance_readiness_v1", "governance_readiness,passed_gates"),
    ]);
    if (!mission.ok || !governance.ok) return respond({ error: "read_unavailable" }, 503);
    const [missions, gates] = await Promise.all([mission.json(), governance.json()]);
    if (!Array.isArray(missions) || !Array.isArray(gates) || missions.length !== 1 || gates.length !== 1) {
      return respond({ error: "missing_mission" }, 503);
    }
    return respond({
      mission_id: MISSION,
      readiness: missions[0].readiness,
      governance_readiness: gates[0].governance_readiness,
      passed_gates: gates[0].passed_gates,
      verified_evidence: missions[0].verified_evidence_count,
      open_risks: missions[0].open_risks,
      sent_receipts: missions[0].sent_receipts,
      acknowledged_receipts: missions[0].acknowledged_receipts,
      read_only: true,
      unattended_execution_verified: false,
    });
  } catch {
    return respond({ error: "read_unavailable" }, 503);
  }
});
