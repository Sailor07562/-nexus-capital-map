/* Read-only renderer. It accepts only a declared local fixture or future approved adapter envelope. */
(() => {
  const payload = window.NexusCommandTowerMock;
  const allowedStates = new Set(["verified", "inferred", "unknown", "failed", "blocked", "frozen"]);
  if (!payload || payload.data_mode !== "mock" || !payload.rows) return;

  const state = (value) => allowedStates.has(value) ? value : "unknown";
  const label = (value) => state(value).replace(/^./, letter => letter.toUpperCase());
  const dot = (value) => `<span class="status ${state(value)}"><span class="dot"></span>${label(value)}</span>`;
  const summary = payload.rows.command_summary || {};
  const cards = document.querySelectorAll(".grid .card");
  if (cards.length >= 4) {
    cards[0].querySelector(".v").textContent = summary.current_cycle || "—";
    cards[1].querySelector(".v").textContent = `${summary.system_health?.verified ?? 0} / ${summary.system_health?.total ?? 0}`;
    cards[2].querySelector(".v").textContent = String(summary.open_attention ?? 0);
    cards[3].querySelector(".v").textContent = summary.promotion_state || "HOLD";
  }

  const healthBody = document.querySelector("#health tbody");
  if (healthBody && Array.isArray(payload.rows.system_health)) {
    healthBody.innerHTML = payload.rows.system_health.map(row => `
      <tr><td><strong>${row.service}</strong><br><span class="quiet">${row.environment}</span></td>
      <td>${row.authority_system}</td><td>${dot(row.verification_state)}</td>
      <td class="quiet">${row.evidence_reference || "No evidence reference"}</td></tr>`).join("");
  }

  const attention = document.querySelector("#attention .stack");
  if (attention && Array.isArray(payload.rows.attention)) {
    attention.innerHTML = payload.rows.attention.map(row => `
      <div class="item"><strong class="${state(row.verification_state)}">${row.summary}</strong>
      <p>${label(row.verification_state)} · ${row.evidence_reference || "No evidence reference"}</p></div>`).join("");
  }

  const footer = document.querySelector(".footer");
  if (footer) footer.textContent = `Data mode: ${payload.data_mode} · Contract ${payload.contract_version} · No database connection · No automation controls · No credentials`;
})();
