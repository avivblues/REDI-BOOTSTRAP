const REFRESH_MS = 30_000;
let lastData = null;
let refreshTimer = null;

const $ = (sel) => document.querySelector(sel);

function stateLabel(state) {
  const map = { up: "Operational", degraded: "Degraded", down: "Down", unknown: "Unknown" };
  return map[state] || state;
}

function overallBadge(overall) {
  const el = $("#overall-badge");
  el.className = "badge";
  if (overall === "healthy") {
    el.classList.add("badge-healthy");
    el.textContent = "All systems operational";
  } else if (overall === "degraded") {
    el.classList.add("badge-degraded");
    el.textContent = "Partial degradation";
  } else {
    el.classList.add("badge-critical");
    el.textContent = "Critical — check hosts";
  }
}

function renderNodes(nodes) {
  const grid = $("#nodes-grid");
  grid.innerHTML = nodes.map((n) => `
    <article class="node-card state-${n.state}">
      <h3><span class="state-dot" aria-hidden="true"></span>${escapeHtml(n.id)}</h3>
      <p class="node-role">${escapeHtml(n.role)}</p>
      <div class="node-ips">
        ${n.mesh_ip ? `<span class="ip-chip">mesh ${escapeHtml(n.mesh_ip)}</span>` : ""}
        ${n.public_ip ? `<span class="ip-chip">public ${escapeHtml(n.public_ip)}</span>` : ""}
      </div>
      <ul class="check-list">
        ${n.checks.map((c) => `
          <li>
            <span>${escapeHtml(c.name)}</span>
            <span class="${c.ok ? "check-ok" : "check-fail"}">${c.ok ? "✓" : "✗"}</span>
          </li>
        `).join("")}
      </ul>
      <p class="muted" style="margin:0.5rem 0 0;font-size:0.75rem">${escapeHtml(n.summary)} · ${stateLabel(n.state)}</p>
    </article>
  `).join("");
}

function renderFailover(rows) {
  const body = $("#failover-body");
  body.innerHTML = rows.map((r) => {
    const pillClass = r.active_label === "Failover" ? "failover"
      : r.active_label === "Unavailable" ? "down" : "";
    const activeText = r.active_node
      ? `${r.active_node} (${r.active_label})`
      : "—";
    return `
      <tr>
        <td><strong>${escapeHtml(r.label)}</strong></td>
        <td>
          ${escapeHtml(r.primary.node)}
          <span class="muted"> · ${stateLabel(r.primary_state)}</span>
        </td>
        <td>
          ${r.secondary ? `${escapeHtml(r.secondary.node)} <span class="muted">· ${stateLabel(r.secondary_state || "unknown")}</span>` : "—"}
        </td>
        <td><span class="active-pill ${pillClass}">${escapeHtml(activeText)}</span></td>
      </tr>
    `;
  }).join("");
}

function renderServices(servicesData) {
  const root = $("#services-root");
  const query = ($("#service-search").value || "").toLowerCase();
  const filter = $("#status-filter").value;

  root.innerHTML = servicesData.categories.map((cat) => {
    const items = cat.services.filter((s) => {
      if (filter !== "all" && s.status !== filter) return false;
      if (!query) return true;
      return s.name.toLowerCase().includes(query) || s.host.toLowerCase().includes(query);
    });
    if (items.length === 0) return "";

    return `
      <div class="category">
        <h3 class="category-title"><span>${cat.icon}</span> ${escapeHtml(cat.title)}</h3>
        <div class="services-grid">
          ${items.map((s) => serviceCard(s)).join("")}
        </div>
      </div>
    `;
  }).join("");
}

function serviceCard(s) {
  const isLive = s.status === "production";
  const cls = isLive ? "" : "disabled";
  const href = isLive ? s.url : "#";
  return `
    <a class="service-card ${cls}" href="${href}" ${isLive ? 'target="_blank" rel="noopener"' : ""}>
      <h4>${escapeHtml(s.name)}</h4>
      <div class="service-host">${escapeHtml(s.host)}</div>
      <div class="service-badges">
        <span class="svc-badge ${isLive ? "svc-live" : "svc-planned"}">${isLive ? "Live" : "Planned"}</span>
        ${s.mesh ? '<span class="svc-badge svc-mesh">Mesh VPN</span>' : ""}
      </div>
      ${s.note ? `<p class="muted" style="margin:0.5rem 0 0;font-size:0.75rem">${escapeHtml(s.note)}</p>` : ""}
    </a>
  `;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function fetchStatus() {
  const btn = $("#refresh-btn");
  btn.disabled = true;
  try {
    const res = await fetch("/api/status", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    lastData = data;
    overallBadge(data.overall);
    renderNodes(data.nodes);
    renderFailover(data.failover);
    renderServices(data.services);

    const ts = new Date(data.generated_at);
    $("#probe-time").textContent = `Probed in ${data.probe_ms}ms · ${ts.toLocaleString()}`;
    $("#footer-ts").textContent = ts.toISOString();
  } catch (err) {
    $("#overall-badge").className = "badge badge-critical";
    $("#overall-badge").textContent = "Status API unreachable";
    console.error(err);
  } finally {
    btn.disabled = false;
  }
}

function scheduleRefresh() {
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = setInterval(fetchStatus, REFRESH_MS);
}

$("#refresh-btn").addEventListener("click", fetchStatus);
$("#service-search").addEventListener("input", () => {
  if (lastData) renderServices(lastData.services);
});
$("#status-filter").addEventListener("change", () => {
  if (lastData) renderServices(lastData.services);
});

fetchStatus().then(scheduleRefresh);
