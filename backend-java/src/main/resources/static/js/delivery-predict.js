const nav = `
  <div class="brand"><div class="mark">LT</div><div>
    <strong>Logi Twin</strong><small>AI operations layer</small>
  </div></div>
  <div class="workspace"><div class="workspace-badge">N</div><div>
    <strong>Northstar Supply</strong><small>Global network</small>
  </div><span>⌄</span></div>
  <div class="nav-title">Control room</div>
  <nav class="nav">
    <a href="dashboard.html" data-page="dashboard"><span>◌</span>
      <div class="nav-copy"><strong>Network overview</strong>
        <small>Live control tower</small></div></a>
    <a href="disruptions.html" data-page="disruptions"><span>!</span>
      <div class="nav-copy"><strong>Disruption control</strong>
        <small>4 scenarios active</small></div><b class="count">4</b></a>
    <a href="demand.html" data-page="demand"><span>⌁</span>
      <div class="nav-copy"><strong>Demand signals</strong>
        <small>Next 14 days</small></div></a>
    <a href="routes.html" data-page="routes"><span>↗</span>
      <div class="nav-copy"><strong>Fleet & routes</strong>
        <small>27 lanes in motion</small></div></a>
    <a href="delivery-predict.html" data-page="delivery-predict"><span>◷</span>
      <div class="nav-copy"><strong>Exact delivery dates</strong>
        <small>Prediction engine</small></div></a>
  </nav>
  <div class="nav-title space">Workspace</div>
  <nav class="nav">
    <a href="inventory.html" data-page="inventory"><span>◇</span>
      <div class="nav-copy"><strong>Inventory health</strong>
        <small>Safety stock & cover</small></div></a>
    <a href="reports.html" data-page="reports"><span>▤</span>
      <div class="nav-copy"><strong>Reports</strong>
        <small>Decision history</small></div></a>
    <a href="settings.html" data-page="settings"><span>⚙</span>
      <div class="nav-copy"><strong>Settings</strong>
        <small>Rules & integrations</small></div></a>
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
  document.querySelector("#sidebar").innerHTML = nav;
  const page = location.pathname.split("/").pop().replace(".html", "");
  document.querySelector(`[data-page="${page}"]`)?.classList.add("active");
}

async function predictDate() {
  const shipmentId = Number(document.querySelector("#shipment").value);
  if (!Number.isInteger(shipmentId) || shipmentId < 1) {
    toast("Enter a valid numeric shipment ID");
    return;
  }
  try {
    const result = await window.logiApi.apiFetch("/api/delivery/predict", {
      method: "POST",
      body: JSON.stringify({ shipmentId }),
    });
    const date = new Date(result.predictedDeliveryAt);
    document.querySelector("#result-title").textContent = `${result.shipmentCode} · delivery prediction`;
    document.querySelector("#result-date").textContent = date.toLocaleString();
    document.querySelector("#result-copy").textContent =
      `Transit ${result.transitHours} hours plus ${result.disruptionDelayHours} disruption hours.`;
    document.querySelector("#prediction-result").classList.add("visible");
    toast(`Prediction calculated with ${result.confidencePercent}% confidence`);
  } catch (error) {
    toast(error.message);
  }
}

setupPage();
document.querySelector("#predict").addEventListener("click", predictDate);
document.querySelector("#refresh")?.addEventListener("click", event => {
  event.currentTarget.textContent = "Predictions refreshed ✓";
  toast("Use Predict exact date to recalculate a shipment from live data");
});
document.querySelector("#search")?.addEventListener("input", event => {
  const query = event.target.value.toLowerCase();
  document.querySelectorAll("[data-search]").forEach(item => {
    item.hidden = query && !item.dataset.search.toLowerCase().includes(query);
  });
});
