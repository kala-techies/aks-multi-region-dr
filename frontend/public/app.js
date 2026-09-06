const API = window.APP_CONFIG.API_BASE_URL;

const state = {
  services: [],
  incidents: [],
  filter: "all",
  apiKey: sessionStorage.getItem("resilientops_api_key") || "",
};

function el(sel, root = document) {
  return root.querySelector(sel);
}

async function api(path, options = {}) {
  const headers = Object.assign({ "Content-Type": "application/json" }, options.headers || {});
  const resp = await fetch(`${API}${path}`, { ...options, headers });
  if (!resp.ok) {
    let detail = resp.statusText;
    try {
      detail = (await resp.json()).detail || detail;
    } catch (_) {
      /* body wasn't JSON */
    }
    throw new Error(`${resp.status}: ${detail}`);
  }
  return resp.status === 204 ? null : resp.json();
}

function authHeaders() {
  return state.apiKey ? { "X-API-Key": state.apiKey } : {};
}

function requireApiKey(action) {
  if (state.apiKey) return action();
  const dialog = el("#key-dialog");
  dialog.showModal();
  el("#key-form").onsubmit = (e) => {
    e.preventDefault();
    const value = el("#key-input").value.trim();
    if (!value) return;
    state.apiKey = value;
    sessionStorage.setItem("resilientops_api_key", value);
    dialog.close();
    action();
  };
}

el("#key-cancel").addEventListener("click", () => el("#key-dialog").close());

const BANNER_COPY = {
  operational: { cls: "ok", text: "All systems operational" },
  degraded_performance: { cls: "warn", text: "Degraded performance on one or more services" },
  partial_outage: { cls: "high", text: "Partial outage affecting one or more services" },
  major_outage: { cls: "crit", text: "Major outage — critical incident in progress" },
};

async function loadSummary() {
  try {
    const health = await api("/healthz");
    el("#region-badge").textContent = `region: ${health.region}`;
    el("#stat-region").textContent = health.region;
    el("#foot-meta").textContent = `Connected to ${API}`;
  } catch (err) {
    el("#region-badge").textContent = "region: unreachable";
    el("#foot-meta").textContent = `Could not reach API at ${API} — ${err.message}`;
  }

  try {
    const status = await api("/status");
    const banner = el("#status-banner");
    const copy = BANNER_COPY[status.overall] || { cls: "warn", text: status.overall.replace(/_/g, " ") };
    banner.className = `status-banner ${copy.cls}`;
    el("#status-banner-text").textContent = copy.text;
    el("#stat-services").textContent = status.services_count;
    el("#stat-open").textContent = status.open_incidents;
  } catch (err) {
    el("#status-banner").className = "status-banner crit";
    el("#status-banner-text").textContent = "Status unavailable";
  }

  el("#last-updated").textContent = `updated ${new Date().toLocaleTimeString()}`;
}

async function loadServices() {
  state.services = await api("/services?limit=100");
  renderServiceOptions();
}

function serviceHasOpenIncident(serviceId) {
  return state.incidents.some((i) => i.service_id === serviceId && i.status !== "resolved");
}

function renderServices() {
  const container = el("#services-list");
  if (state.services.length === 0) {
    container.innerHTML = `<div class="empty">No services registered yet — click "Register service" to add the first one.</div>`;
    return;
  }
  container.innerHTML = state.services
    .map((s) => {
      const affected = serviceHasOpenIncident(s.id);
      return `
      <div class="service-card">
        <h3><span class="status-dot ${affected ? "affected" : "healthy"}" title="${affected ? "Open incident" : "Healthy"}"></span>${escapeHtml(s.name)}</h3>
        <p>${escapeHtml(s.description || "No description")}</p>
        <span class="owner">${escapeHtml(s.owner_team || "unassigned")}</span>
      </div>`;
    })
    .join("");
}

function renderServiceOptions() {
  const select = el("#incident-service-select");
  select.innerHTML = state.services
    .map((s) => `<option value="${s.id}">${escapeHtml(s.name)}</option>`)
    .join("");
}

function serviceName(id) {
  const svc = state.services.find((s) => s.id === id);
  return svc ? svc.name : `service #${id}`;
}

async function loadIncidents() {
  // "open" covers investigating/identified/monitoring - fetch all and filter
  // client-side since the API's status filter is exact-match, not a set.
  state.incidents = await api("/incidents?limit=100");
  renderIncidents();
}

function renderIncidents() {
  const container = el("#incidents-list");
  let items = state.incidents;
  if (state.filter === "open") items = items.filter((i) => i.status !== "resolved");
  if (state.filter === "resolved") items = items.filter((i) => i.status === "resolved");

  if (items.length === 0) {
    container.innerHTML = `<div class="empty">No incidents in this view.</div>`;
    return;
  }

  container.innerHTML = items
    .map(
      (i) => `
      <div class="incident" data-id="${i.id}">
        <div class="incident-head" data-toggle="${i.id}">
          <span class="sev sev-${i.severity}">${i.severity}</span>
          <span class="incident-title">${escapeHtml(i.title)}</span>
          <span class="incident-service">${escapeHtml(serviceName(i.service_id))}</span>
          <span class="incident-status">${i.status}</span>
          <span class="chevron">&#8250;</span>
        </div>
        <div class="incident-body"></div>
      </div>`
    )
    .join("");

  container.querySelectorAll("[data-toggle]").forEach((headEl) => {
    headEl.addEventListener("click", () => toggleIncident(headEl));
  });
}

function toggleIncident(headEl) {
  const wrapper = headEl.closest(".incident");
  const isOpen = wrapper.classList.contains("is-open");
  wrapper.parentElement.querySelectorAll(".incident.is-open").forEach((n) => {
    if (n !== wrapper) n.classList.remove("is-open");
  });
  wrapper.classList.toggle("is-open", !isOpen);
  if (!isOpen) renderIncidentDetail(wrapper);
}

function renderIncidentDetail(wrapper) {
  const id = Number(wrapper.dataset.id);
  const incident = state.incidents.find((i) => i.id === id);
  const body = wrapper.querySelector(".incident-body");
  const tpl = el("#incident-detail-template").content.cloneNode(true);

  const updatesEl = tpl.querySelector(".incident-updates");
  updatesEl.innerHTML = incident.updates
    .map(
      (u) => `<div class="update-row">${escapeHtml(u.message)}<time>${new Date(u.created_at).toLocaleString()} — ${u.status_at_time}</time></div>`
    )
    .join("");

  const actions = tpl.querySelector(".incident-actions");
  if (incident.status !== "resolved") {
    const nextStatus = { investigating: "identified", identified: "monitoring", monitoring: "resolved" }[incident.status];
    if (nextStatus) {
      const btn = document.createElement("button");
      btn.className = "btn btn-primary btn-sm";
      btn.textContent = `Mark ${nextStatus}`;
      btn.onclick = () => requireApiKey(() => patchIncident(id, { status: nextStatus }));
      actions.appendChild(btn);
    }
  }

  const form = tpl.querySelector(".update-form");
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const message = new FormData(form).get("message");
    if (!message) return;
    requireApiKey(() => postIncidentUpdate(id, message, form));
  });

  body.innerHTML = "";
  body.appendChild(tpl);
}

async function patchIncident(id, payload) {
  await api(`/incidents/${id}`, { method: "PATCH", headers: authHeaders(), body: JSON.stringify(payload) });
  await loadIncidents();
  renderServices();
  await loadSummary();
  const wrapper = document.querySelector(`.incident[data-id="${id}"]`);
  if (wrapper) {
    wrapper.classList.add("is-open");
    renderIncidentDetail(wrapper);
  }
}

async function postIncidentUpdate(id, message, form) {
  await api(`/incidents/${id}/updates`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ message }),
  });
  form.reset();
  await loadIncidents();
  const wrapper = document.querySelector(`.incident[data-id="${id}"]`);
  if (wrapper) {
    wrapper.classList.add("is-open");
    renderIncidentDetail(wrapper);
  }
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str ?? "";
  return div.innerHTML;
}

// --- filter buttons ---
document.querySelectorAll(".filter-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".filter-btn").forEach((b) => b.classList.remove("is-active"));
    btn.classList.add("is-active");
    state.filter = btn.dataset.filter;
    renderIncidents();
  });
});

// --- register service dialog ---
el("#btn-new-service").addEventListener("click", () => requireApiKey(() => el("#service-dialog").showModal()));
document.querySelectorAll("#service-dialog [data-close]").forEach((b) => b.addEventListener("click", () => el("#service-dialog").close()));
el("#service-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const data = Object.fromEntries(new FormData(e.target));
  try {
    await api("/services", { method: "POST", headers: authHeaders(), body: JSON.stringify(data) });
    el("#service-dialog").close();
    e.target.reset();
    await loadServices();
    renderServices();
    await loadSummary();
  } catch (err) {
    alert(err.message);
  }
});

// --- report incident dialog ---
el("#btn-new-incident").addEventListener("click", () =>
  requireApiKey(() => {
    if (state.services.length === 0) {
      alert("Register a service first.");
      return;
    }
    el("#incident-dialog").showModal();
  })
);
document.querySelectorAll("#incident-dialog [data-close]").forEach((b) => b.addEventListener("click", () => el("#incident-dialog").close()));
el("#incident-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const data = Object.fromEntries(new FormData(e.target));
  const serviceId = data.service_id;
  delete data.service_id;
  try {
    await api(`/services/${serviceId}/incidents`, { method: "POST", headers: authHeaders(), body: JSON.stringify(data) });
    el("#incident-dialog").close();
    e.target.reset();
    await loadIncidents();
    renderServices();
    await loadSummary();
  } catch (err) {
    alert(err.message);
  }
});

async function refreshAll() {
  await loadSummary();
  await loadServices();
  await loadIncidents(); // must resolve before renderServices() so the health dot reflects current incidents
  renderServices();
}

refreshAll();
setInterval(refreshAll, 15000); // poll - fine for a demo; a real build would use SSE/websocket
