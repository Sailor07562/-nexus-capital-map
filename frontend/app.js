const pages = [
  ["operations-dashboard", "Operations Dashboard", "Single operational entry point for the Nexus ecosystem."],
  ["nexus-registry", "Nexus Registry", "Reserved for governed Nexus entities and their canonical references."],
  ["mission-registry", "Mission Registry", "Reserved for authorized missions, scope, and lifecycle state."],
  ["persistent-operational-state", "Persistent Operational State (POSE)", "Reserved for durable operating context and verified handoff state."],
  ["decision-queue", "Decision Queue", "Reserved for reviewable decisions and their authority boundaries."],
  ["session-journal", "Session Journal", "Reserved for session records, continuity, and evidence links."],
  ["live-telemetry", "Live Telemetry", "Reserved for future governed telemetry presentation. No telemetry is implemented."],
  ["engine-orchestrator", "Engine Orchestrator", "Reserved for governed engine status and routing. No orchestration is implemented."],
  ["nexus-program-office", "Nexus Program Office", "Reserved for program coordination and authorized operational planning."]
];

const navigation = document.querySelector("#navigation");
const title = document.querySelector("#page-title");
const content = document.querySelector("#page-content");

const esc = (value) => String(value).replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character]);

async function renderLiveStatus() {
  content.innerHTML = `<article class="verification-card"><div class="verification-heading"><div><p class="eyebrow">B-001 · Read-only evidence</p><h2>Live-Status Verification</h2><p>Only proven conditions are marked verified. This lane does not execute SQL, writes, automations, or credential flows.</p></div><button id="refresh-status" type="button">Verify now</button></div><p class="loading">Collecting status evidence…</p></article>`;
  try {
    const response = await fetch("/api/live-status", { cache: "no-store" });
    if (!response.ok) throw new Error(`Status endpoint returned ${response.status}`);
    const payload = await response.json();
    const rows = payload.checks.map((check) => `<tr><td>${esc(check.system)}</td><td><span class="state ${esc(check.state)}">${esc(check.state)}</span></td><td>${esc(check.summary)}</td><td>${esc(check.evidence)}</td><td>${esc(new Date(check.observedAt).toLocaleTimeString())}</td></tr>`).join("");
    content.innerHTML = `<article class="verification-card"><div class="verification-heading"><div><p class="eyebrow">B-001 · Read-only evidence</p><h2>Live-Status Verification</h2><p>Only proven conditions are marked verified. This lane does not execute SQL, writes, automations, or credential flows.</p></div><button id="refresh-status" type="button">Verify now</button></div><p class="evidence-time">Evidence refreshed ${esc(new Date(payload.generatedAt).toLocaleString())}</p><div class="table-wrap"><table><thead><tr><th>System</th><th>State</th><th>Observation</th><th>Evidence</th><th>Observed</th></tr></thead><tbody>${rows}</tbody></table></div></article>`;
  } catch (error) {
    content.innerHTML = `<article class="verification-card"><p class="eyebrow">B-001 · Verification failed</p><h2>Status unavailable</h2><p>${esc(error.message)}</p><button id="refresh-status" type="button">Try again</button></article>`;
  }
  document.querySelector("#refresh-status")?.addEventListener("click", renderLiveStatus);
}

function route() {
  const key = location.hash.replace(/^#\//, "") || pages[0][0];
  const active = pages.find(([id]) => id === key) || pages[0];
  title.textContent = active[1];
  if (active[0] === "operations-dashboard") {
    renderLiveStatus();
    navigation.querySelectorAll("a").forEach((link) => link.classList.toggle("active", link.dataset.page === active[0]));
    return;
  }
  content.innerHTML = `
    <article class="placeholder-card">
      <p class="eyebrow">B-000 · Placeholder page</p>
      <h2>${active[1]}</h2>
      <p>${active[2]}</p>
      <div class="placeholder-state"><span></span> Not implemented in B-000</div>
      <p class="boundary">No business logic, SQL, telemetry, automation, credentials, or live connector activity is present in this page.</p>
    </article>`;
  navigation.querySelectorAll("a").forEach((link) => link.classList.toggle("active", link.dataset.page === active[0]));
}

navigation.innerHTML = pages.map(([id, label]) => `<a href="#/${id}" data-page="${id}">${label}</a>`).join("");
window.addEventListener("hashchange", route);
route();
