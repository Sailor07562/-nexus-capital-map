import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { basename, extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { config } from "./config.js";
import { loadCapitalPortfolio, loadCapitalSnapshot, loadCapitalStocks, loadCommandTowerAdapters, loadCommandTowerData, loadCommandTowerTools, loadXlpReceipt } from "./ct-data.js";
import { collectLiveStatus } from "./live-status.js";

const here = fileURLToPath(new URL(".", import.meta.url));
const frontendRoot = join(here, "..", "frontend");
const contentTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".md": "text/markdown; charset=utf-8",
  ".pdf": "application/pdf",
  ".sql": "text/plain; charset=utf-8",
  ".csv": "text/csv; charset=utf-8",
  ".svg": "image/svg+xml"
};

const evidenceFiles = new Map([
  ["capital-map-html", "C:/Users/GBT/Documents/Codex/2026-09-15/nexus-capital-map-carryover/outputs/Nexus-Capital-Map-Decision-Engine.html"],
  ["decision-engine-csv", "C:/Users/GBT/Documents/Codex/2026-09-15/nexus-capital-map-carryover/outputs/nexus-decision-engine.csv"],
  ["state-lane-pack", "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/State_Research_Radar_Lane_Pack_2026-09-23.md"],
  ["state-migration-124", "C:/Users/GBT/Documents/Codex/Nexus-canon-review-20260923/postgres/migrations/historical/124_nexus_research_radar_state_lanes.sql"],
  ["xlp-workflow", "C:/Users/GBT/Documents/Codex/2026-09-15/nexus-capital-map-carryover/work/xlp-final.json"],
  ["xlp-submission-receipt", "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/Nexus_Paper_Receipt_Reconciliation_2026-09-23.md"],
  ["xlp-ledger-receipt", "C:/Users/GBT/Documents/Codex/2026-09-25/referenced-chatgpt-conversation-this-is-an-2/outputs/NEXUS_TRADE_LEDGER_BUILD_RECEIPT_20260925.md"]
]);
const statePdfRoot = "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/State_Research_Radar_PDF_Filings_2026-09-23";

function sendFile(response, filePath) {
  response.writeHead(200, { "content-type": contentTypes[extname(filePath)] || "application/octet-stream" });
  createReadStream(filePath).pipe(response);
}

const server = createServer(async (request, response) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.writeHead(405, { allow: "GET, HEAD" });
    response.end("Method not allowed");
    return;
  }

  const requestedPath = new URL(request.url, "http://localhost").pathname;
  if (requestedPath === "/api/live-status") {
    const status = await collectLiveStatus();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(status));
    return;
  }
  if (requestedPath === "/api/capital-snapshot") {
    const snapshot = loadCapitalSnapshot();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(snapshot));
    return;
  }
  if (requestedPath === "/api/stocks") {
    const stocks = loadCapitalStocks();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(stocks));
    return;
  }
  if (requestedPath === "/api/portfolio") {
    const portfolio = loadCapitalPortfolio();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(portfolio));
    return;
  }
  if (requestedPath === "/api/xlp-receipt") {
    const xlp = loadXlpReceipt();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(xlp));
    return;
  }
  if (requestedPath === "/api/tools") {
    const tools = loadCommandTowerTools();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(tools));
    return;
  }
  if (requestedPath === "/api/adapters") {
    const adapters = loadCommandTowerAdapters();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(adapters));
    return;
  }
  if (requestedPath === "/api/data") {
    const data = loadCommandTowerData();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(data));
    return;
  }
  if (requestedPath.startsWith("/evidence/file/")) {
    const key = decodeURIComponent(requestedPath.replace("/evidence/file/", ""));
    const evidencePath = evidenceFiles.get(key);
    if (evidencePath && existsSync(evidencePath) && statSync(evidencePath).isFile()) {
      if (request.method === "HEAD") {
        response.writeHead(200, { "content-type": contentTypes[extname(evidencePath)] || "application/octet-stream" });
        response.end();
        return;
      }
      sendFile(response, evidencePath);
      return;
    }
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("Evidence file not found");
    return;
  }
  if (requestedPath.startsWith("/evidence/state-pdf/")) {
    const requestedName = basename(decodeURIComponent(requestedPath.replace("/evidence/state-pdf/", "")));
    const evidencePath = normalize(join(statePdfRoot, requestedName));
    const safePath = evidencePath.startsWith(normalize(statePdfRoot)) && existsSync(evidencePath) && statSync(evidencePath).isFile();
    if (safePath) {
      if (request.method === "HEAD") {
        response.writeHead(200, { "content-type": "application/pdf" });
        response.end();
        return;
      }
      sendFile(response, evidencePath);
      return;
    }
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("State PDF evidence not found");
    return;
  }
  const relativePath = requestedPath === "/" ? "index.html" : requestedPath.replace(/^\/+/, "");
  const filePath = normalize(join(frontendRoot, relativePath));
  const safePath = filePath.startsWith(frontendRoot) && existsSync(filePath) && statSync(filePath).isFile();

  if (safePath) {
    if (request.method === "HEAD") {
      response.writeHead(200, { "content-type": contentTypes[extname(filePath)] || "application/octet-stream" });
      response.end();
      return;
    }
    sendFile(response, filePath);
    return;
  }

  // SPA fallback: page routing is client-side only in B-000.
  sendFile(response, join(frontendRoot, "index.html"));
});

server.listen(config.port, config.host, () => {
  console.log(`${config.applicationName} B-001 verification listening on http://localhost:${config.port}`);
});
