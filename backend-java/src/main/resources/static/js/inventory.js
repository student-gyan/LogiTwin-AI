const nav = `
  <div class="brand"><div class="mark">LT</div><div>
    <strong>Logi Twin</strong><small>AI operations layer</small>
  </div></div>
  <div class="workspace"><div class="workspace-badge">N</div><div>
    <strong>Northstar Supply</strong><small>Global network</small>
  </div><span>⌄</span></div>
  <div class="nav-title">Control room</div>
  <nav class="nav">
    <a href="dashboard.html" data-page="dashboard"><span>◌</span><div class="nav-copy">
      <strong>Network overview</strong><small>Live control tower</small>
    </div></a>
    <a href="disruptions.html" data-page="disruptions"><span>!</span>
      <div class="nav-copy"><strong>Disruption control</strong>
        <small>4 scenarios active</small></div><b class="count">4</b>
    </a>
    <a href="demand.html" data-page="demand"><span>⌁</span><div class="nav-copy">
      <strong>Demand signals</strong><small>Next 14 days</small>
    </div></a>
    <a href="routes.html" data-page="routes"><span>↗</span><div class="nav-copy">
      <strong>Fleet & routes</strong><small>27 lanes in motion</small>
    </div></a>
    <a href="delivery-predict.html" data-page="delivery-predict"><span>◷</span>
      <div class="nav-copy"><strong>Exact delivery dates</strong>
        <small>Prediction engine</small></div>
    </a>
  </nav>
  <div class="nav-title space">Workspace</div>
  <nav class="nav">
    <a href="inventory.html" data-page="inventory"><span>◇</span><div class="nav-copy">
      <strong>Inventory health</strong><small>Safety stock & cover</small>
    </div></a>
    <a href="reports.html" data-page="reports"><span>▤</span><div class="nav-copy">
      <strong>Reports</strong><small>Decision history</small>
    </div></a>
    <a href="settings.html" data-page="settings"><span>⚙</span><div class="nav-copy">
      <strong>Settings</strong><small>Rules & integrations</small>
    </div></a>
  </nav>
  <div class="side-status"><i class="pulse"></i><div>
    <strong>Twin status: learning</strong>
    <small>18 live feeds · refresh 06:10 UTC</small>
  </div></div>
  <div class="side-footer"><span>● All systems normal</span>
    <span>v2.4.1</span></div>
`;

function toast(message) {
  let box = document.querySelector(".toast");
  if (!box) {
    box = document.createElement("div");
    box.className = "toast";
    document.body.appendChild(box);
  }
  box.textContent = message;
  box.classList.add("show");
  clearTimeout(window.toastTimer);
  window.toastTimer = setTimeout(() => box.classList.remove("show"), 2600);
}

function setupPage() {
  const sidebar = document.querySelector("#sidebar");
  if (sidebar) sidebar.innerHTML = nav;
  const page = location.pathname.split("/").pop().replace(".html", "");
  document.querySelector(`[data-page="${page}"]`)?.classList.add("active");
  const role = localStorage.getItem("logiRole");
  const roleLabel = document.querySelector("#role-label");
  if (role && roleLabel) roleLabel.textContent = role;
}

setupPage();
async function loadInventory() {
  try {
    const rows = await window.logiApi.apiFetch("/api/inventory/health");
    const entries = document.querySelectorAll(".workspace-grid .report-row");
    rows.slice(0, entries.length).forEach((item, index) => {
      const entry = entries[index];
      entry.dataset.search = `${item.itemName} ${item.city} ${item.healthStatus}`;
      entry.querySelector(".report-main strong").textContent = item.itemName;
      entry.querySelector(".report-main small").textContent = `${item.city} · ${item.daysCover ?? "—"} days cover · ${item.availableUnits.toLocaleString()} units`;
      const status = entry.querySelector(".status");
      status.textContent = item.healthStatus;
      status.className = `status ${item.healthStatus === "healthy" ? "good" : item.healthStatus === "watch" ? "watch" : "risk"}`;
    });
  } catch (error) {
    toast(error.message);
  }
}
loadInventory();
document.querySelector("#acknowledge")?.addEventListener("click", () => {
  toast("Scenario acknowledged");
});
document.querySelector("#simulate")?.addEventListener("click", event => {
  event.currentTarget.textContent = "Simulation complete ✓";
  loadInventory();
  toast("Analysis refreshed from live network data");
});
document.querySelector("#approve")?.addEventListener("click", () => {
  toast("Action approved and added to dispatch queue");
});
document.querySelector("#generate")?.addEventListener("click", () => {
  toast("Report generated from the active twin model");
});
document.querySelector("#save")?.addEventListener("click", () => {
  toast("Settings saved successfully");
});
document.querySelector("#search")?.addEventListener("input", event => {
  const query = event.target.value.toLowerCase();
  document.querySelectorAll("[data-search]").forEach(item => {
    item.hidden = query && !item.dataset.search.toLowerCase().includes(query);
  });
});
document.querySelectorAll(".toggle").forEach(toggle => {
  toggle.addEventListener("click", () => toggle.classList.toggle("on"));
});
document.querySelectorAll(".tabs button").forEach(tab => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tabs button").forEach(item => {
      item.classList.remove("active");
    });
    tab.classList.add("active");
    toast(`${tab.textContent} settings opened`);
  });
});
