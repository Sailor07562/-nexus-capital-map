const layers = [
  { id: "overview", label: "Overview", purpose: "Unified control plane for Nexus health, evidence, gates, and movement.", mission: "Is Nexus operationally coherent?", items: ["Mission-first operations", "Read-only cockpit", "Evidence before action", "Governed receipts"] },
  { id: "nexus-watch", label: "Nexus Watch", purpose: "One receipt and read-only monitoring across the governed surface.", mission: "What needs attention right now?", items: ["PostgreSQL evidence", "n8n health", "Future trades", "Next allowed action", "Provenance"] },
  { id: "instruments", label: "Capital Map Coverage", purpose: "Operator-first coverage of instruments, workflows, paper boundaries, and authority.", mission: "Where is capital exposed?", items: ["Portfolio holdings", "ETF allocations", "Decision Engine rows", "Watchlists", "Paper boundaries"] },
  { id: "future-trades", label: "Future Trades", purpose: "Proposals, scheduled intents, and broker-open Paper visibility.", mission: "What is proposed or scheduled?", items: ["Proposals", "Scheduled intents", "Broker-open Paper orders", "Timing rules", "Readback boundary"] },
  { id: "intake-engine", label: "Intake Engine", purpose: "Interchangeable first-contact adapters under the fixed Governance Constitution.", mission: "What evidence may enter the system?", items: ["First contact", "Domain lanes", "Validation", "Deduplication", "Quarantine", "Human admission"] },
  { id: "adapter-registry", label: "Adapter Registry", purpose: "One map of first-contact connectors, fetch-only by design.", mission: "Are connections bounded and observable?", items: ["PostgreSQL", "n8n", "Airtable", "Google Drive", "Tracker", "Broker boundary"] },
  { id: "governance-engine", label: "Governance Engine", purpose: "Authority registry and boundary checks with the human stop intact.", mission: "Is execution authorized?", items: ["Purpose", "Authority", "Policy", "Human review", "Promotion gate", "Receipt"] },
  { id: "infrastructure-context", label: "Infrastructure Context", purpose: "Signal context and replay checks for governed infrastructure research.", mission: "What context and lineage support this signal?", items: ["Signal lineage", "Context checks", "Replay anchor", "Evidence quality", "Read-only aggregate"] },
  { id: "capital-deployment", label: "Capital Deployment Boundary", purpose: "Distributed controls where human approval remains the stop.", mission: "Can any capital move?", items: ["Policy gate", "Market gate", "Risk gate", "Cash gate", "Broker gate", "Human approval"] },
  { id: "paper-reconciliation", label: "Paper Receipt Reconciliation", purpose: "Snapshot parity and currentness hold for Paper receipts; no new submission.", mission: "What actually happened in Paper?", items: ["Proposal", "Submission", "Broker status", "Fill state", "PostgreSQL receipt", "Currentness hold"] },
  { id: "workflow-hygiene", label: "Workflow Hygiene", purpose: "Read-only disposition map for n8n workflows with no activation or deletion.", mission: "Which workflows are current, stale, or held?", items: ["Inventory", "Duplicate check", "Staleness", "Disposition", "Archive candidate", "No mutation"] },
  { id: "architecture", label: "Nexus Architecture", purpose: "Canonical system map with lifecycle, authority, and source-of-truth relationships visible.", mission: "How does Nexus fit together?", items: ["PostgreSQL authority", "n8n executor", "CT cockpit", "Drive evidence", "Human authority", "Lifecycle"] },
  { id: "investing", label: "Investing Engine", purpose: "Aggregate-only investing engine visibility with research and execution boundaries intact.", mission: "What is the engine allowed to know or do?", items: ["Engine status", "Candidates", "Policies", "Shadow intents", "Paper boundary", "Live trading gated"] },
  { id: "engine-canon", label: "Engine Canon", purpose: "Full future-engine registry with declared purpose, boundaries, and receipts.", mission: "Which engines exist and under what rules?", items: ["Formal engines", "Candidates", "Purpose", "Authority", "Lifecycle", "Verification"] },
  { id: "maintenance", label: "Maintenance Queue", purpose: "Bounded read-only first-officer queue for findings that need review.", mission: "What should be inspected next?", items: ["Attention findings", "Health checks", "Provenance", "Safe next action", "Human review", "No destructive mutation"] },
  { id: "data", label: "Data", purpose: "Shows where truth and evidence live, including State Research Radar.", mission: "Is the data trustworthy?", items: ["PostgreSQL operational truth", "Drive doctrine and evidence", "Tracker observation", "Airtable legacy mirror", "State Research Radar"] },
  { id: "tools", label: "Tools", purpose: "Execution-capable tools stay visible but gated.", mission: "What can safely execute?", items: ["n8n workflows", "SQL migrations", "GitHub commits", "Alpaca gateways", "Promotion tools", "Backup tools"] },
  { id: "live-status", label: "Live Status", purpose: "Read-only runtime probes from the local CT app.", mission: "What is verifiably reachable right now?", items: [] },
  { id: "automation", label: "n8n Sandbox", purpose: "Local n8n source inventory and read-only visibility.", mission: "What automation is present without changing it?", items: ["Workflow inventory", "Activation state", "Source evidence", "Execution boundary", "No mutation"] },
  { id: "foundation", label: "Foundation", purpose: "Future-engine governance principles and the frozen operating foundation.", mission: "What principles must every engine obey?", items: ["Declared purpose", "Explicit boundary", "PostgreSQL records", "Governance decides", "Human authorizes"] },
  { id: "boundaries", label: "Boundaries", purpose: "Connection, authority, and evidence boundaries for the whole Command Tower.", mission: "What must remain separate?", items: ["PostgreSQL authority", "n8n executor", "CT cockpit", "Broker boundary", "No credentials", "No hidden execution"] }
];

const statusRows = [
  ["PostgreSQL", "Authority", "Operational truth, mission registry, receipts", "Read-only checks only from CT"],
  ["n8n", "Executor", "Workflow execution and logs", "No workflow mutation from CT"],
  ["Command Tower", "Cockpit", "Read-only operational surface", "No source-of-truth writes"],
  ["Tracker", "Observation", "Human-visible review and status", "No execution authority"],
  ["Airtable", "Mirror / registry", "Human-readable structured context", "Does not override PostgreSQL"],
  ["Alpaca", "Broker boundary", "Paper/live broker visibility", "No order without explicit action authority"]
];

const navigation = document.querySelector("#navigation");
const title = document.querySelector("#page-title");
const content = document.querySelector("#page-content");
const esc = (value) => String(value).replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character]);
const money = (value) => value === null || value === undefined ? "—" : new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(value);
const number = (value, digits = 3) => value === null || value === undefined ? "—" : new Intl.NumberFormat("en-US", { maximumFractionDigits: digits }).format(value);
const pct = (value) => value === null || value === undefined ? "—" : `${Number(value).toFixed(2)}%`;
const link = (href, label, className = "evidence-link") => href ? `<a class="${className}" href="${esc(href)}" target="_blank" rel="noreferrer">${esc(label || href)}</a>` : "";

function layerCard(layer) {
  return `
    <article class="layer-card">
      <p class="eyebrow">Command Tower v6</p>
      <h2>${esc(layer.label)}</h2>
      <p>${esc(layer.purpose)}</p>
      <div class="mission-line"><span>Mission</span>${esc(layer.mission)}</div>
      <ul>${layer.items.map((item) => `<li>${esc(item)}</li>`).join("")}</ul>
    </article>`;
}

function renderOverview() {
  content.innerHTML = `
    <section class="hero-card">
      <p class="eyebrow">Nexus Command Tower v6</p>
      <h2>Unified Control Plane</h2>
      <p>Command Tower is restored as the read-only cockpit for Nexus: systems, stocks, tools, adapters, governance, and live status. PostgreSQL remains authority; n8n executes; CT observes.</p>
      <div class="boundary-grid">
        <div><strong>No SQL writes</strong><span>CT does not mutate PostgreSQL.</span></div>
        <div><strong>No broker action</strong><span>Orders require separate action authority.</span></div>
        <div><strong>No hidden execution</strong><span>Tools are visible, not auto-fired.</span></div>
        <div><strong>Evidence first</strong><span>Receipts and readback drive status.</span></div>
      </div>
    </section>
    <section class="layer-grid">${layers.filter((layer) => layer.id !== "overview" && layer.id !== "live-status").map(layerCard).join("")}</section>
    <section class="matrix-card">
      <h2>Source-of-truth matrix</h2>
      <div class="table-wrap"><table><thead><tr><th>System</th><th>Role</th><th>What CT shows</th><th>Boundary</th></tr></thead><tbody>
        ${statusRows.map((row) => `<tr>${row.map((cell) => `<td>${esc(cell)}</td>`).join("")}</tr>`).join("")}
      </tbody></table></div>
    </section>`;
}

async function renderLiveStatus() {
  content.innerHTML = `<article class="verification-card"><div class="verification-heading"><div><p class="eyebrow">B-002 · authenticated read-only evidence</p><h2>Live Status</h2><p>PostgreSQL is marked verified only after the read-only identity query succeeds as nexus_command_tower_ro. This lane does not execute SQL writes, broker calls, or n8n mutations.</p></div><button id="refresh-status" type="button">Verify now</button></div><p class="loading">Collecting status evidence…</p></article>`;
  try {
    const response = await fetch("/api/live-status", { cache: "no-store" });
    if (!response.ok) throw new Error(`Status endpoint returned ${response.status}`);
    const payload = await response.json();
    const rows = payload.checks.map((check) => `<tr><td>${esc(check.system)}</td><td><span class="state ${esc(check.state)}">${esc(check.state)}</span></td><td>${esc(check.summary)}</td><td>${esc(check.evidence)}</td><td>${esc(new Date(check.observedAt).toLocaleTimeString())}</td></tr>`).join("");
    content.innerHTML = `<article class="verification-card"><div class="verification-heading"><div><p class="eyebrow">B-002 · authenticated read-only evidence</p><h2>Live Status</h2><p>Only proven conditions are marked verified. PostgreSQL requires an authenticated nexus_command_tower_ro identity query; this page observes and does not operate.</p></div><button id="refresh-status" type="button">Verify now</button></div><p class="evidence-time">Evidence refreshed ${esc(new Date(payload.generatedAt).toLocaleString())}</p><div class="table-wrap"><table><thead><tr><th>System</th><th>State</th><th>Observation</th><th>Evidence</th><th>Observed</th></tr></thead><tbody>${rows}</tbody></table></div></article>`;
  } catch (error) {
    content.innerHTML = `<article class="verification-card"><p class="eyebrow">Verification failed</p><h2>Status unavailable</h2><p>${esc(error.message)}</p><button id="refresh-status" type="button">Try again</button></article>`;
  }
  document.querySelector("#refresh-status")?.addEventListener("click", renderLiveStatus);
}

async function renderStocks() {
  content.innerHTML = `<article class="verification-card"><p class="eyebrow">Read-only evidence</p><h2>Loading portfolio evidence…</h2><p class="loading">Pulling the local Capital Map portfolio, Decision Engine rows, and XLP receipts.</p></article>`;
  try {
    const response = await fetch("/api/capital-snapshot", { cache: "no-store" });
    if (!response.ok) throw new Error(`Capital snapshot returned ${response.status}`);
    const payload = await response.json();
    const portfolio = payload.portfolio;
    const stocks = payload.stocks;
    const xlp = payload.xlp;
    const xlpHolding = portfolio.rows.find((row) => row.ticker === "XLP");
    const portfolioRows = portfolio.rows.map((row) => `
      <tr>
        <td><strong>${esc(row.ticker)}</strong><span class="tag">${esc(row.instrumentType)}</span></td>
        <td>${esc(row.securityName)}<span class="tag">${esc((row.accountNames || []).join(" · "))}</span></td>
        <td class="num">${number(row.quantity, 6)}</td>
        <td class="num">${money(row.marketValue)}</td>
        <td class="num">${pct(row.consolidatedWeightPct)}</td>
        <td class="num ${Number(row.totalGainLoss) < 0 ? "loss" : "gain"}">${money(row.totalGainLoss)}<span class="tag">${pct(row.totalGainLossPct)}</span></td>
      </tr>`).join("");
    const decisionRows = stocks.rows.map((row) => `
      <tr>
        <td><strong>${esc(row.ticker)}</strong><span class="tag">${esc(row.instrumentType)}</span></td>
        <td>${esc(row.recommendation)}<span class="tag">${esc(row.readiness)}</span></td>
        <td class="num">${money(row.capturedMarketValue)}</td>
        <td>${esc(row.blockers || "No blocker listed")}</td>
      </tr>`).join("");

    content.innerHTML = `
      <section class="hero-card">
        <p class="eyebrow">Stocks · actual portfolio</p>
        <h2>Your Reconciled Portfolio</h2>
        <p>Restored from the frozen Capital Map portfolio evidence. This is read-only CT display: no SQL write, no broker request, no trade action.</p>
        <div class="summary-grid">
          <div><strong>${esc(portfolio.summary.rowCount)}</strong><span>holdings</span></div>
          <div><strong>${money(portfolio.summary.marketValue)}</strong><span>captured securities value</span></div>
          <div><strong>${esc(portfolio.summary.accountCount)}</strong><span>accounts represented</span></div>
          <div><strong>${esc(new Date(portfolio.source.generatedAt || portfolio.source.modifiedAt).toLocaleString())}</strong><span>evidence timestamp</span></div>
        </div>
      </section>
      <section class="split-grid">
        <article class="data-card">
          <p class="eyebrow">XLP holding</p>
          <h2>${xlpHolding ? money(xlpHolding.marketValue) : "Not found"}</h2>
          <p>${xlpHolding ? `${number(xlpHolding.quantity, 6)} shares · ${pct(xlpHolding.consolidatedWeightPct)} weight · observed ${esc(new Date(xlpHolding.latestObservedAt).toLocaleString())}` : "No XLP row found in restored portfolio evidence."}</p>
        </article>
        <article class="data-card">
          <p class="eyebrow">XLP paper receipt</p>
          <h2>${esc(xlp.ledgerReceipt.executionState || "unknown")}</h2>
          <p>Client order ${esc(xlp.submissionReceipt?.clientOrderId || "—")} · submission HTTP ${esc(xlp.submissionReceipt?.httpStatus || "—")} · filled quantity ${esc(xlp.ledgerReceipt.filledQuantity || "—")} · notional ${esc(xlp.ledgerReceipt.notional || "—")}</p>
          <p class="source-note">Broker order ${esc(xlp.ledgerReceipt.brokerOrderId || "—")}. Submitted to Alpaca Paper, then ledgered as expired without a fill.</p>
          <p>${link(xlp.workflow.sourceUrl, "Official XLP source")} ${link(xlp.sources.submissionReceipt.href, "Submission receipt")} ${link(xlp.sources.ledgerReceipt.href, "Ledger receipt")}</p>
        </article>
      </section>
      <section class="matrix-card">
        <h2>Portfolio positions</h2>
        <div class="table-wrap"><table class="portfolio-table"><thead><tr><th>Ticker</th><th>Name / accounts</th><th class="num">Quantity</th><th class="num">Market value</th><th class="num">Weight</th><th class="num">Gain/Loss</th></tr></thead><tbody>${portfolioRows}</tbody></table></div>
        <p class="source-note">Source: ${link(portfolio.source.href, portfolio.source.path)}</p>
      </section>
      <section class="matrix-card">
        <h2>Decision Engine status</h2>
        <p class="muted">Separate from ownership. These rows explain why proposals remain blocked until valuation, liquidity, debt-priority, reserve, overlap, and role gates are resolved.</p>
        <div class="table-wrap"><table><thead><tr><th>Ticker</th><th>Decision</th><th class="num">Captured value</th><th>Blockers</th></tr></thead><tbody>${decisionRows}</tbody></table></div>
        <p class="source-note">Source: ${link(stocks.source.href, stocks.source.path)}</p>
      </section>`;
  } catch (error) {
    content.innerHTML = `<article class="verification-card"><p class="eyebrow">Portfolio unavailable</p><h2>Could not load stocks</h2><p>${esc(error.message)}</p></article>`;
  }
}

async function renderData() {
  content.innerHTML = `<article class="verification-card"><p class="eyebrow">Read-only evidence</p><h2>Loading data lanes…</h2><p class="loading">Pulling State Research Radar, portfolio evidence, and approved read-only views.</p></article>`;
  try {
    const response = await fetch("/api/data", { cache: "no-store" });
    if (!response.ok) throw new Error(`Data endpoint returned ${response.status}`);
    const payload = await response.json();
    const radar = payload.stateResearch;
    const stateRows = radar.states.map((state) => {
      const memo = state.memo;
      const seeded = state.seededLane;
      const memoLinks = memo?.evidence?.length ? memo.evidence.map((item) => link(item.url, item.label, "tag link-tag")).join("") : "";
      return `
        <tr>
          <td><strong>${esc(state.stateName)}</strong>${seeded ? `<span class="tag">${esc(seeded.stateCode)} · ${esc(seeded.status)}</span>` : `<span class="tag">lane-pack only</span>`}</td>
          <td>${seeded ? esc(seeded.regulator) : "—"}${seeded ? `<span class="tag">${esc(seeded.isoRto.join(" · "))}</span>` : ""}</td>
          <td>${memo ? esc(memo.workingSignal) : "Seeded in migration 124; detailed memo text not present in the lane pack."}${memoLinks}</td>
          <td>${esc(memo?.status || "pending_human_review")}${seeded ? `<span class="tag">${esc(seeded.pendingSignals)} pending signals · ${esc(seeded.candidateLinks)} candidate links</span>` : ""}</td>
          <td>${state.pdfs.length ? state.pdfs.map((pdf) => link(pdf.href, pdf.file, "tag link-tag")).join("") : "—"}</td>
        </tr>`;
    }).join("");
    const sourceRows = Object.entries(radar.sources).map(([name, source]) => `
      <tr><td><strong>${esc(name)}</strong></td><td>${source.href ? link(source.href, source.path) : esc(source.path)}</td><td>${source.modifiedAt ? esc(new Date(source.modifiedAt).toLocaleString()) : "directory"}</td></tr>`).join("");

    content.innerHTML = `
      <section class="hero-card">
        <p class="eyebrow">Data · State Research Radar</p>
        <h2>States research restored</h2>
        <p>State research is back on the Data page as a read-only lane. It remains research-candidate / human-review only; no thesis promotion and no trade action.</p>
        <div class="summary-grid">
          <div><strong>${esc(radar.summary.stateCount)}</strong><span>states surfaced</span></div>
          <div><strong>${esc(radar.summary.seededLaneCount)}</strong><span>PostgreSQL-seeded lanes</span></div>
          <div><strong>${esc(radar.summary.memoStateCount)}</strong><span>lane-pack memo states</span></div>
          <div><strong>${esc(radar.summary.pdfCount)}</strong><span>saved PDF filings</span></div>
        </div>
      </section>
      <section class="matrix-card">
        <h2>Research boundary</h2>
        <div class="boundary-grid">
          <div><strong>Read-only</strong><span>${esc(radar.authority.readOnlyResearch)}</span></div>
          <div><strong>Human review</strong><span>${esc(radar.authority.humanReviewRequired)}</span></div>
          <div><strong>Thesis promotion</strong><span>${esc(radar.authority.thesisPromotionAllowed ? "allowed" : "blocked")}</span></div>
          <div><strong>Trade action</strong><span>${esc(radar.authority.tradeActionAllowed ? "allowed" : "blocked")}</span></div>
        </div>
      </section>
      <section class="matrix-card">
        <h2>States research lanes</h2>
        <div class="table-wrap"><table><thead><tr><th>State</th><th>Regulator / grid</th><th>Working signal / source links</th><th>Status</th><th>Local PDF evidence</th></tr></thead><tbody>${stateRows}</tbody></table></div>
      </section>
      <section class="matrix-card">
        <h2>Cross-state interpretation</h2>
        <ul>${radar.commonInterpretation.map((item) => `<li>${esc(item)}</li>`).join("")}</ul>
      </section>
      <section class="matrix-card">
        <h2>Evidence sources</h2>
        <div class="table-wrap"><table><thead><tr><th>Source</th><th>Path</th><th>Modified</th></tr></thead><tbody>${sourceRows}</tbody></table></div>
      </section>`;
  } catch (error) {
    content.innerHTML = `<article class="verification-card"><p class="eyebrow">Data unavailable</p><h2>Could not load State Research Radar</h2><p>${esc(error.message)}</p></article>`;
  }
}

async function renderTools() {
  content.innerHTML = `<article class="verification-card"><p class="eyebrow">Read-only evidence</p><h2>Loading tools…</h2><p class="loading">Pulling n8n workflows, CT scripts, and CT endpoint inventory.</p></article>`;
  try {
    const response = await fetch("/api/tools", { cache: "no-store" });
    if (!response.ok) throw new Error(`Tools endpoint returned ${response.status}`);
    const payload = await response.json();
    const activeWorkflows = payload.n8n.workflows.filter((workflow) => workflow.active);
    const inactiveWorkflows = payload.n8n.workflows.filter((workflow) => !workflow.active);
    const workflowRows = payload.n8n.workflows.map((workflow) => `
      <tr>
        <td><strong>${esc(workflow.name)}</strong><span class="tag">${esc(workflow.id)}</span></td>
        <td>${esc(workflow.category)}</td>
        <td><span class="state ${workflow.active ? "verified" : "attention"}">${workflow.active ? "active" : "inactive"}</span></td>
        <td>${workflow.updatedAt ? esc(new Date(workflow.updatedAt).toLocaleString()) : "—"}</td>
      </tr>`).join("");
    const scriptRows = payload.scripts.scripts.map((script) => `
      <tr>
        <td><strong>${esc(script.name)}</strong></td>
        <td>${esc(script.kind)}</td>
        <td class="num">${number(script.bytes, 0)}</td>
        <td>${esc(new Date(script.modifiedAt).toLocaleString())}</td>
      </tr>`).join("");
    const endpointRows = payload.endpoints.map((endpoint) => `
      <tr>
        <td><strong>${esc(endpoint.path)}</strong></td>
        <td>${esc(endpoint.purpose)}</td>
        <td>${endpoint.mutation ? "mutation-capable" : "read-only"}</td>
      </tr>`).join("");

    content.innerHTML = `
      <section class="hero-card">
        <p class="eyebrow">Tools</p>
        <h2>Nexus tool inventory</h2>
        <p>Tools are visible here as evidence-backed capabilities. CT does not fire them from this page.</p>
        <div class="summary-grid">
          <div><strong>${esc(payload.n8n.summary.workflowCount)}</strong><span>n8n workflows</span></div>
          <div><strong>${esc(activeWorkflows.length)}</strong><span>active workflows</span></div>
          <div><strong>${esc(payload.scripts.summary.scriptCount)}</strong><span>CT scripts</span></div>
          <div><strong>${esc(payload.endpoints.length)}</strong><span>local CT endpoints</span></div>
        </div>
      </section>
      <section class="matrix-card">
        <h2>Active workflows</h2>
        <p class="muted">${esc(activeWorkflows.map((workflow) => workflow.name).join(" · ") || "No active workflows found.")}</p>
      </section>
      <section class="matrix-card">
        <h2>n8n workflow inventory</h2>
        <div class="table-wrap"><table><thead><tr><th>Workflow</th><th>Category</th><th>Status</th><th>Updated</th></tr></thead><tbody>${workflowRows}</tbody></table></div>
        <p class="source-note">Source: ${esc(payload.n8n.source.path)}</p>
      </section>
      <section class="matrix-card">
        <h2>Command Tower local tools</h2>
        <div class="table-wrap"><table><thead><tr><th>Script</th><th>Kind</th><th class="num">Bytes</th><th>Modified</th></tr></thead><tbody>${scriptRows}</tbody></table></div>
        <p class="source-note">Source: ${esc(payload.scripts.source.path)}</p>
      </section>
      <section class="matrix-card">
        <h2>CT read-only endpoints</h2>
        <div class="table-wrap"><table><thead><tr><th>Endpoint</th><th>Purpose</th><th>Boundary</th></tr></thead><tbody>${endpointRows}</tbody></table></div>
      </section>`;
  } catch (error) {
    content.innerHTML = `<article class="verification-card"><p class="eyebrow">Tools unavailable</p><h2>Could not load tools</h2><p>${esc(error.message)}</p></article>`;
  }
}

async function renderAdapters() {
  content.innerHTML = `<article class="verification-card"><p class="eyebrow">Read-only evidence</p><h2>Loading adapters…</h2><p class="loading">Pulling PostgreSQL read-only views, external surfaces, connector files, and Thread Adapter routes.</p></article>`;
  try {
    const response = await fetch("/api/adapters", { cache: "no-store" });
    if (!response.ok) throw new Error(`Adapters endpoint returned ${response.status}`);
    const payload = await response.json();
    const surfaceRows = payload.integrationSurfaces.map((surface) => `
      <tr>
        <td><strong>${esc(surface.name)}</strong><span class="tag">${esc(surface.id)}</span></td>
        <td>${esc(surface.type)}</td>
        <td><span class="state verified">${esc(surface.readbackStatus || "verified")}</span></td>
        <td>${esc(surface.state || "—")}</td>
      </tr>`).join("");
    const postgresRows = payload.readOnlyPostgres.approvedViews.map((view) => `
      <tr>
        <td><strong>${esc(view.view)}</strong></td>
        <td>${view.exists ? "exists" : "missing"}</td>
        <td>${view.has_rows ? "has rows" : "no rows"}</td>
        <td class="num">${esc(view.column_count)}</td>
      </tr>`).join("");
    const connectorRows = payload.connectors.connectors.map((connector) => `
      <tr>
        <td><strong>${esc(connector.name)}</strong><span class="tag">${esc(connector.file)}</span></td>
        <td class="num">${number(connector.bytes, 0)}</td>
        <td>${esc(new Date(connector.modifiedAt).toLocaleString())}</td>
      </tr>`).join("");
    const threadRows = payload.threadAdapter.routes.map((route) => `
      <tr>
        <td><strong>${esc(route.route)}</strong><span class="tag">${esc(route.threadId)}</span></td>
        <td>${esc(route.title)}</td>
        <td>${esc(route.purpose)}</td>
      </tr>`).join("");

    content.innerHTML = `
      <section class="hero-card">
        <p class="eyebrow">Adapters</p>
        <h2>Nexus adapter boundary</h2>
        <p>Adapters keep the system connected without letting CT become authority. PostgreSQL remains semantic authority; CT observes and routes.</p>
        <div class="summary-grid">
          <div><strong>${esc(payload.readOnlyPostgres.approvedViews.length)}</strong><span>approved PostgreSQL views</span></div>
          <div><strong>${esc(payload.integrationSurfaces.length)}</strong><span>external surfaces</span></div>
          <div><strong>${esc(payload.connectors.summary.connectorCount)}</strong><span>connector stubs</span></div>
          <div><strong>${esc(payload.threadAdapter.summary.routeCount)}</strong><span>Thread Adapter routes</span></div>
        </div>
      </section>
      <section class="matrix-card">
        <h2>PostgreSQL read-only adapter</h2>
        <p class="muted">Role ${esc(payload.readOnlyPostgres.role)} · default read-only ${esc(payload.readOnlyPostgres.defaultTransactionReadOnly)} · write path ${esc(payload.readOnlyPostgres.writePath)}.</p>
        <div class="table-wrap"><table><thead><tr><th>View</th><th>Exists</th><th>Rows</th><th class="num">Columns</th></tr></thead><tbody>${postgresRows}</tbody></table></div>
      </section>
      <section class="matrix-card">
        <h2>External integration surfaces</h2>
        <div class="table-wrap"><table><thead><tr><th>Surface</th><th>Type</th><th>Status</th><th>State</th></tr></thead><tbody>${surfaceRows}</tbody></table></div>
      </section>
      <section class="matrix-card">
        <h2>Connector files</h2>
        <div class="table-wrap"><table><thead><tr><th>Connector</th><th class="num">Bytes</th><th>Modified</th></tr></thead><tbody>${connectorRows}</tbody></table></div>
      </section>
      <section class="matrix-card">
        <h2>Thread Adapter routes</h2>
        <div class="table-wrap"><table><thead><tr><th>Route / thread</th><th>Room</th><th>Purpose</th></tr></thead><tbody>${threadRows}</tbody></table></div>
        <p class="source-note">Source: ${esc(payload.threadAdapter.source.path)}</p>
      </section>`;
  } catch (error) {
    content.innerHTML = `<article class="verification-card"><p class="eyebrow">Adapters unavailable</p><h2>Could not load adapters</h2><p>${esc(error.message)}</p></article>`;
  }
}

function renderLayer(layer) {
  content.innerHTML = `
    ${layerCard(layer)}
    <section class="matrix-card">
      <h2>${esc(layer.label)} boundary</h2>
      <p class="muted">This surface is restored from the frozen Command Tower v6 operating model. It is a cockpit lane, not a source of authority.</p>
      <div class="boundary-grid">
        <div><strong>Shows</strong><span>${esc(layer.purpose)}</span></div>
        <div><strong>Asks</strong><span>${esc(layer.mission)}</span></div>
        <div><strong>Blocks</strong><span>Mutation without a separate receipt and authority gate.</span></div>
        <div><strong>Next</strong><span>Attach read-only adapters and receipts by lane.</span></div>
      </div>
    </section>`;
}

function route() {
  const key = location.hash.replace(/^#\//, "") || "overview";
  const active = layers.find((layer) => layer.id === key) || layers[0];
  title.textContent = active.label === "Overview" ? "Command Tower" : active.label;
  if (active.id === "overview") renderOverview();
  else if (active.id === "live-status") renderLiveStatus();
  else if (active.id === "data") renderData();
  else if (active.id === "stocks" || active.id === "instruments") renderStocks();
  else if (active.id === "tools") renderTools();
  else if (active.id === "adapters" || active.id === "adapter-registry") renderAdapters();
  else renderLayer(active);
  navigation.querySelectorAll("a").forEach((link) => link.classList.toggle("active", link.dataset.page === active.id));
}

navigation.innerHTML = layers.map((layer) => `<a href="#/${layer.id}" data-page="${layer.id}">${layer.label}</a>`).join("");
window.addEventListener("hashchange", route);
route();
