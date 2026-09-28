import { readdirSync, readFileSync, statSync } from "node:fs";

const sources = {
  capitalMapHtml: "C:/Users/GBT/Documents/Codex/2026-09-15/nexus-capital-map-carryover/outputs/Nexus-Capital-Map-Decision-Engine.html",
  decisionEngineCsv: "C:/Users/GBT/Documents/Codex/2026-09-15/nexus-capital-map-carryover/outputs/nexus-decision-engine.csv",
  n8nWorkflows: "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/live-n8n-workflows-current.json",
  commandTowerScripts: "C:/Users/GBT/Documents/Codex/Nexus-canon-review-20260923/command-tower",
  commandTowerConnectors: "G:/My Drive/Drive-Doc-Capital Map/Nexus Command Tower/NEXUS_COMMAND_TOWER_LAPTOP_READY_20260919 3/nexus-command-tower/app/connectors",
  integrationRegistry: "C:/Users/GBT/Documents/Codex/Nexus-canon-review-20260923/command-tower/command-tower-integration-registry.json",
  readOnlyAdapter: "C:/Users/GBT/Documents/Codex/Nexus-canon-review-20260923/command-tower/command-tower-readonly-adapter.json",
  stateResearchLanePack: "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/State_Research_Radar_Lane_Pack_2026-09-23.md",
  stateResearchMigration: "C:/Users/GBT/Documents/Codex/Nexus-canon-review-20260923/postgres/migrations/historical/124_nexus_research_radar_state_lanes.sql",
  stateResearchPdfDir: "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/State_Research_Radar_PDF_Filings_2026-09-23",
  threadAdapterIndex: "C:/Users/GBT/Documents/Codex/2026-09-18/you-x20/outputs/THREAD_ADAPTER_INDEX_20260927.md",
  xlpWorkflow: "C:/Users/GBT/Documents/Codex/2026-09-15/nexus-capital-map-carryover/work/xlp-final.json",
  xlpSubmissionReceipt: "C:/Users/GBT/Documents/Codex/2026-09-18/create-a-full-nexus-architecture-freeze/work/Nexus_Paper_Receipt_Reconciliation_2026-09-23.md",
  xlpLedgerReceipt: "C:/Users/GBT/Documents/Codex/2026-09-25/referenced-chatgpt-conversation-this-is-an-2/outputs/NEXUS_TRADE_LEDGER_BUILD_RECEIPT_20260925.md"
};

function readEvidenceFile(path) {
  const text = readFileSync(path, "utf8");
  const stats = statSync(path);
  return {
    path,
    text,
    modifiedAt: stats.mtime.toISOString()
  };
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    const next = text[index + 1];

    if (quoted) {
      if (character === "\"" && next === "\"") {
        field += "\"";
        index += 1;
      } else if (character === "\"") {
        quoted = false;
      } else {
        field += character;
      }
      continue;
    }

    if (character === "\"") {
      quoted = true;
    } else if (character === ",") {
      row.push(field);
      field = "";
    } else if (character === "\n") {
      row.push(field.replace(/\r$/, ""));
      rows.push(row);
      row = [];
      field = "";
    } else {
      field += character;
    }
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field.replace(/\r$/, ""));
    rows.push(row);
  }

  const [headers, ...dataRows] = rows.filter((candidate) => candidate.some((value) => value !== ""));
  return dataRows.map((dataRow) => Object.fromEntries(headers.map((header, index) => [header, dataRow[index] ?? ""])));
}

function parseEmbeddedCapitalMap(text) {
  const match = text.match(/<script[^>]*id=["']nexus-data["'][^>]*>([\s\S]*?)<\/script>/i);
  if (!match) throw new Error("Capital Map embedded data block was not found.");
  return JSON.parse(match[1]);
}

function parseStateLanePack(text) {
  const stateSections = [...text.matchAll(/^##\s+([A-Z][A-Za-z ]+)\s*$([\s\S]*?)(?=^##\s+|(?![\s\S]))/gm)];
  return stateSections
    .filter((match) => !["Scope and boundary", "Cross-state interpretation", "Next proof points"].includes(match[1]))
    .map((match) => {
      const body = match[2];
      const signal = body.match(/### Working signal\s*([\s\S]*?)(?=### Evidence)/i)?.[1]?.trim() ?? "";
      const evidenceBlock = body.match(/### Evidence\s*([\s\S]*?)(?=### Review state)/i)?.[1] ?? "";
      const reviewState = body.match(/### Review state\s*([\s\S]*)/i)?.[1]?.trim() ?? "";
      const evidence = evidenceBlock.split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line.startsWith("- "))
        .map((line) => {
          const clean = line.replace(/^-\s+/, "");
          const [label, ...urlParts] = clean.split(": ");
          return { label, url: urlParts.join(": ") || null };
        });
      return {
        stateName: match[1],
        status: reviewState.includes("pending_human_review") ? "pending_human_review" : "research_candidate",
        workingSignal: signal.replace(/\s+/g, " "),
        evidence
      };
    });
}

function listPdfEvidence() {
  return readdirSync(sources.stateResearchPdfDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".pdf"))
    .map((entry) => {
      const path = `${sources.stateResearchPdfDir}/${entry.name}`;
      const stats = statSync(path);
      const stateName = entry.name.split("_")[0];
      return {
        stateName,
        file: entry.name,
        href: `/evidence/state-pdf/${encodeURIComponent(entry.name)}`,
        bytes: stats.size,
        modifiedAt: stats.mtime.toISOString()
      };
    });
}

function loadStateResearch() {
  const packEvidence = readEvidenceFile(sources.stateResearchLanePack);
  const migrationEvidence = readEvidenceFile(sources.stateResearchMigration);
  const pdfEvidence = listPdfEvidence();
  const memoStates = parseStateLanePack(packEvidence.text);
  const seededLanes = [
    { stateCode: "VA", stateName: "Virginia", regulator: "Virginia State Corporation Commission", isoRto: ["PJM"], status: "verified_seeded", pendingSignals: 3, candidateLinks: 9 },
    { stateCode: "WI", stateName: "Wisconsin", regulator: "Public Service Commission of Wisconsin", isoRto: ["MISO"], status: "verified_seeded", pendingSignals: 3, candidateLinks: 9 },
    { stateCode: "IN", stateName: "Indiana", regulator: "Indiana Utility Regulatory Commission", isoRto: ["MISO", "PJM"], status: "verified_seeded", pendingSignals: 2, candidateLinks: 6 },
    { stateCode: "TX", stateName: "Texas", regulator: "Public Utility Commission of Texas", isoRto: ["ERCOT", "MISO", "SPP"], status: "verified_seeded", pendingSignals: 3, candidateLinks: 10 },
    { stateCode: "MI", stateName: "Michigan", regulator: "Michigan Public Service Commission", isoRto: ["MISO", "PJM"], status: "verified_seeded", pendingSignals: 3, candidateLinks: 9 }
  ];
  const allStateNames = [...new Set([...memoStates.map((state) => state.stateName), ...seededLanes.map((lane) => lane.stateName), ...pdfEvidence.map((pdf) => pdf.stateName)])].sort();

  return {
    generatedAt: new Date().toISOString(),
    status: "research_candidate",
    lane: "infrastructure_power_transmission",
    authority: {
      readOnlyResearch: true,
      humanReviewRequired: true,
      thesisPromotionAllowed: false,
      tradeActionAllowed: false
    },
    summary: {
      stateCount: allStateNames.length,
      seededLaneCount: seededLanes.length,
      memoStateCount: memoStates.length,
      pdfCount: pdfEvidence.length
    },
    states: allStateNames.map((stateName) => ({
      stateName,
      seededLane: seededLanes.find((lane) => lane.stateName === stateName) ?? null,
      memo: memoStates.find((state) => state.stateName === stateName) ?? null,
      pdfs: pdfEvidence.filter((pdf) => pdf.stateName === stateName)
    })),
    commonInterpretation: [
      "Large-load requests, tariffs, permits, and dockets are research signals, not proof of energized load.",
      "Project-specific proof is required before linking a signal to issuer revenue, vendor awards, or portfolio action.",
      "All lanes remain pending human review with thesis promotion and trade action blocked."
    ],
    sources: {
      lanePack: { path: packEvidence.path, modifiedAt: packEvidence.modifiedAt, href: "/evidence/file/state-lane-pack" },
      migration124: { path: migrationEvidence.path, modifiedAt: migrationEvidence.modifiedAt, href: "/evidence/file/state-migration-124" },
      pdfDirectory: { path: sources.stateResearchPdfDir }
    }
  };
}

function numberOrNull(value) {
  if (value === undefined || value === null || value === "") return null;
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function percentOrNull(value) {
  const numeric = numberOrNull(value);
  return numeric === null ? null : numeric * 100;
}

function extractMarkdownValue(text, label) {
  const pattern = new RegExp(`-\\s*${label}:\\s*\`?([^\\n\`]+)\`?`, "i");
  return text.match(pattern)?.[1]?.trim() ?? null;
}

function parseXlpSubmissionReceipt(text) {
  const row = text.split(/\r?\n/).find((line) => line.includes("NEXUS-XLP-PAPER-20260922-001"));
  if (!row) return null;
  const cells = row.split("|").map((cell) => cell.replace(/`/g, "").trim()).filter(Boolean);
  return {
    ticker: cells[0] ?? "XLP",
    clientOrderId: cells[1] ?? "NEXUS-XLP-PAPER-20260922-001",
    receiptId: cells[2] ?? null,
    result: cells[3] ?? null,
    httpStatus: cells[4] ?? null,
    brokerStatusAtSubmission: cells[5] ?? null
  };
}

function findDeepString(value, pattern) {
  if (typeof value === "string") return pattern.test(value) ? value : null;
  if (!value || typeof value !== "object") return null;
  for (const child of Object.values(value)) {
    const found = findDeepString(child, pattern);
    if (found) return found;
  }
  return null;
}

function classifyWorkflow(name) {
  if (/PAPER|ALPACA|ORDER/i.test(name)) return "broker-boundary";
  if (/CAPITAL-MAP|XLP|JEPI|JEPQ|POWL/i.test(name)) return "capital-map-intake";
  if (/COMMAND-TOWER|CT/i.test(name)) return "command-tower";
  if (/CONSUMER/i.test(name)) return "consumer-intelligence";
  if (/RESEARCH-RADAR/i.test(name)) return "research-radar";
  if (/ROOM|REGISTRY/i.test(name)) return "room-registry";
  return "n8n-workflow";
}

function loadN8nWorkflowToolset() {
  const evidence = readEvidenceFile(sources.n8nWorkflows);
  const workflows = JSON.parse(evidence.text).map((workflow) => ({
    id: workflow.id,
    name: workflow.name,
    active: Boolean(workflow.active),
    archived: Boolean(workflow.isArchived),
    updatedAt: workflow.updatedAt ?? null,
    category: classifyWorkflow(workflow.name ?? "")
  }));

  return {
    source: { path: evidence.path, modifiedAt: evidence.modifiedAt, href: "/evidence/file/decision-engine-csv" },
    summary: {
      workflowCount: workflows.length,
      activeCount: workflows.filter((workflow) => workflow.active).length,
      archivedCount: workflows.filter((workflow) => workflow.archived).length
    },
    workflows
  };
}

function loadCommandTowerScripts() {
  const files = readdirSync(sources.commandTowerScripts, { withFileTypes: true })
    .filter((entry) => entry.isFile() && /^(Verify|Invoke|Read|Serve|Create)-/.test(entry.name))
    .map((entry) => {
      const path = `${sources.commandTowerScripts}/${entry.name}`;
      const stats = statSync(path);
      return {
        name: entry.name,
        kind: entry.name.endsWith(".ps1") ? "powershell" : entry.name.endsWith(".mjs") ? "node" : "file",
        bytes: stats.size,
        modifiedAt: stats.mtime.toISOString()
      };
    });
  return {
    source: { path: sources.commandTowerScripts },
    summary: { scriptCount: files.length },
    scripts: files
  };
}

function loadConnectorFiles() {
  const files = readdirSync(sources.commandTowerConnectors, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".js") && entry.name !== "index.js")
    .map((entry) => {
      const path = `${sources.commandTowerConnectors}/${entry.name}`;
      const stats = statSync(path);
      return {
        name: entry.name.replace(/\.js$/, ""),
        file: entry.name,
        modifiedAt: stats.mtime.toISOString(),
        bytes: stats.size
      };
    });
  return {
    source: { path: sources.commandTowerConnectors },
    summary: { connectorCount: files.length },
    connectors: files
  };
}

function loadThreadAdapterRoutes() {
  const evidence = readEvidenceFile(sources.threadAdapterIndex);
  const routes = [];
  const lines = evidence.text.split(/\r?\n/);
  let currentRoute = null;
  let currentThread = null;
  for (const line of lines) {
    const route = line.match(/^##\s+(.+)$/);
    if (route) {
      currentRoute = route[1].trim();
      currentThread = null;
      continue;
    }
    const thread = line.match(/^-\s+`([^`]+)`\s+-\s+(.+)$/);
    if (thread && currentRoute) {
      currentThread = {
        route: currentRoute,
        threadId: thread[1],
        title: thread[2],
        purpose: "",
        blocked: []
      };
      routes.push(currentThread);
      continue;
    }
    if (currentThread) {
      const purpose = line.match(/^\s+-\s+Purpose:\s+(.+)$/);
      const blocked = line.match(/^\s+-\s+Blocked:\s+(.+)$/);
      if (purpose) currentThread.purpose = purpose[1].trim();
      if (blocked) currentThread.blocked = blocked[1].split(",").map((item) => item.trim());
    }
  }
  return {
    source: { path: evidence.path, modifiedAt: evidence.modifiedAt },
    summary: { routeCount: new Set(routes.map((route) => route.route)).size, threadCount: routes.length },
    routes
  };
}

function loadAdapterRegistry() {
  const integrationEvidence = readEvidenceFile(sources.integrationRegistry);
  const readOnlyEvidence = readEvidenceFile(sources.readOnlyAdapter);
  const integration = JSON.parse(integrationEvidence.text);
  const readOnly = JSON.parse(readOnlyEvidence.text);
  const connectors = loadConnectorFiles();
  const threadAdapter = loadThreadAdapterRoutes();

  return {
    generatedAt: new Date().toISOString(),
    authority: integration.authority,
    integrationSurfaces: (integration.surfaces ?? []).map((surface) => ({
      id: surface.surface_id,
      type: surface.surface_type,
      name: surface.name,
      state: surface.state,
      readbackStatus: surface.readback_status,
      objectCount: Array.isArray(surface.mapped_objects) ? surface.mapped_objects.length : 0
    })),
    readOnlyPostgres: {
      adapter: readOnly.adapter,
      mode: readOnly.mode,
      role: readOnly.identity?.role,
      defaultTransactionReadOnly: Boolean(readOnly.identity?.default_transaction_read_only),
      writePath: Boolean(readOnly.identity?.write_path),
      approvedViews: readOnly.approved_views ?? [],
      summaries: readOnly.summary_readback?.views ?? []
    },
    connectors,
    threadAdapter,
    sources: {
      integrationRegistry: { path: integrationEvidence.path, modifiedAt: integrationEvidence.modifiedAt },
      readOnlyAdapter: { path: readOnlyEvidence.path, modifiedAt: readOnlyEvidence.modifiedAt },
      connectorDirectory: { path: sources.commandTowerConnectors },
      threadAdapterIndex: threadAdapter.source
    }
  };
}

function loadTools() {
  const n8n = loadN8nWorkflowToolset();
  const scripts = loadCommandTowerScripts();
  return {
    generatedAt: new Date().toISOString(),
    n8n,
    scripts,
    endpoints: [
      { path: "/api/live-status", purpose: "Runtime reachability probe", mutation: false },
      { path: "/api/portfolio", purpose: "Reconciled portfolio evidence", mutation: false },
      { path: "/api/stocks", purpose: "Decision Engine stock status", mutation: false },
      { path: "/api/xlp-receipt", purpose: "XLP workflow and receipt readback", mutation: false },
      { path: "/api/tools", purpose: "Tools/workflows/scripts inventory", mutation: false },
      { path: "/api/adapters", purpose: "Adapter registry and read-only boundary inventory", mutation: false }
    ],
    boundary: {
      noBrokerSubmit: true,
      noSqlWrite: true,
      noN8nMutation: true,
      displayOnly: true
    }
  };
}

function loadStocks() {
  const evidence = readEvidenceFile(sources.decisionEngineCsv);
  const rows = parseCsv(evidence.text).map((row) => ({
    ticker: row.ticker,
    securityName: row.security_name,
    instrumentType: row.instrument_type,
    recommendation: row.recommendation,
    readiness: row.readiness,
    thesisState: row.thesis_state,
    valuationState: row.valuation_state,
    capturedMarketValue: numberOrNull(row.captured_market_value),
    capturedPortfolioWeightPct: percentOrNull(row.captured_portfolio_weight),
    knownIndirectOverlapValue: numberOrNull(row.known_indirect_overlap_value),
    blockers: row.blockers,
    nextRequiredEvidence: row.next_required_evidence,
    reviewDueOn: row.review_due_on,
    sourceTitle: row.source_title,
    sourceUri: row.source_uri,
    contextAsOf: row.context_as_of,
    deploymentAuthorized: row.deployment_authorized === "True",
    laneReviewStatus: row.lane_review_status
  }));

  const capturedMarketValue = rows.reduce((total, row) => total + (row.capturedMarketValue ?? 0), 0);
  const blocked = rows.filter((row) => row.readiness === "blocked").length;
  const deploymentAuthorized = rows.filter((row) => row.deploymentAuthorized).length;

  return {
    generatedAt: new Date().toISOString(),
    source: { path: evidence.path, modifiedAt: evidence.modifiedAt },
    summary: {
      rowCount: rows.length,
      blocked,
      deploymentAuthorized,
      capturedMarketValue
    },
    rows
  };
}

function loadPortfolio() {
  const evidence = readEvidenceFile(sources.capitalMapHtml);
  const data = parseEmbeddedCapitalMap(evidence.text);
  const rows = Array.isArray(data.portfolio) ? data.portfolio : [];
  const marketValue = rows.reduce((total, row) => total + (numberOrNull(row.market_value) ?? 0), 0);
  const accountNames = [...new Set(rows.flatMap((row) => Array.isArray(row.account_names) ? row.account_names : []))];

  return {
    generatedAt: new Date().toISOString(),
    source: { path: evidence.path, modifiedAt: evidence.modifiedAt, generatedAt: data.generated_at ?? null, href: "/evidence/file/capital-map-html" },
    summary: {
      rowCount: rows.length,
      accountCount: accountNames.length,
      marketValue,
      accountNames
    },
    rows: rows.map((row) => ({
      ticker: row.ticker,
      securityName: row.security_name,
      instrumentType: row.instrument_type,
      accountCount: row.account_count,
      accountNames: row.account_names ?? [],
      quantity: numberOrNull(row.quantity),
      costBasis: numberOrNull(row.cost_basis),
      marketValue: numberOrNull(row.market_value),
      totalGainLoss: numberOrNull(row.total_gain_loss),
      totalGainLossPct: numberOrNull(row.total_gain_loss_pct),
      consolidatedWeightPct: numberOrNull(row.consolidated_weight),
      latestObservedAt: row.latest_observed_at,
      sourceLabels: row.source_labels ?? []
    }))
  };
}

function loadXlp() {
  const workflowEvidence = readEvidenceFile(sources.xlpWorkflow);
  const submissionEvidence = readEvidenceFile(sources.xlpSubmissionReceipt);
  const ledgerEvidence = readEvidenceFile(sources.xlpLedgerReceipt);
  const workflow = JSON.parse(workflowEvidence.text);
  const workflowRecord = Array.isArray(workflow) ? workflow[0] : workflow;
  const nodes = Array.isArray(workflowRecord.nodes) ? workflowRecord.nodes : [];
  const sourceUrl = findDeepString(workflowRecord, /ssga\.com\/us\/en\/individual\/etfs\/state-street-consumer-staples-select-sector-spdr-etf-xlp/i);

  return {
    generatedAt: new Date().toISOString(),
    workflow: {
      id: workflowRecord.id ?? null,
      name: workflowRecord.name ?? null,
      active: Boolean(workflowRecord.active),
      createdAt: workflowRecord.createdAt ?? null,
      updatedAt: workflowRecord.updatedAt ?? null,
      sourceUrl,
      nodeNames: nodes.map((node) => node.name).filter(Boolean)
    },
    submissionReceipt: parseXlpSubmissionReceipt(submissionEvidence.text),
    ledgerReceipt: {
      executionState: extractMarkdownValue(ledgerEvidence.text, "XLP state"),
      notional: extractMarkdownValue(ledgerEvidence.text, "XLP notional"),
      filledQuantity: extractMarkdownValue(ledgerEvidence.text, "XLP filled quantity"),
      brokerOrderId: extractMarkdownValue(ledgerEvidence.text, "XLP broker order ID"),
      ledgerRows: extractMarkdownValue(ledgerEvidence.text, "Ledger rows"),
      filledRows: extractMarkdownValue(ledgerEvidence.text, "Filled rows"),
      submittedRows: extractMarkdownValue(ledgerEvidence.text, "Submitted rows")
    },
    boundary: {
      noNewOrders: true,
      noBrokerRequest: true,
      noSqlWrite: true,
      displayOnly: true
    },
    sources: {
      workflow: { path: workflowEvidence.path, modifiedAt: workflowEvidence.modifiedAt, href: "/evidence/file/xlp-workflow" },
      submissionReceipt: { path: submissionEvidence.path, modifiedAt: submissionEvidence.modifiedAt, href: "/evidence/file/xlp-submission-receipt" },
      ledgerReceipt: { path: ledgerEvidence.path, modifiedAt: ledgerEvidence.modifiedAt, href: "/evidence/file/xlp-ledger-receipt" }
    }
  };
}

export function loadCapitalSnapshot() {
  return {
    generatedAt: new Date().toISOString(),
    portfolio: loadPortfolio(),
    stocks: loadStocks(),
    stateResearch: loadStateResearch(),
    tools: loadTools(),
    adapters: loadAdapterRegistry(),
    xlp: loadXlp()
  };
}

export function loadCapitalPortfolio() {
  return loadPortfolio();
}

export function loadCapitalStocks() {
  return loadStocks();
}

export function loadXlpReceipt() {
  return loadXlp();
}

export function loadCommandTowerTools() {
  return loadTools();
}

export function loadCommandTowerAdapters() {
  return loadAdapterRegistry();
}

export function loadCommandTowerData() {
  return {
    generatedAt: new Date().toISOString(),
    stateResearch: loadStateResearch(),
    portfolio: loadPortfolio(),
    readOnlyAdapter: loadAdapterRegistry().readOnlyPostgres
  };
}
