(() => {
  const API_BASE = window.LOGI_API_BASE || "";
  const TOKEN_KEY = "logiToken";

  function token() {
    return localStorage.getItem(TOKEN_KEY);
  }

  function logout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem("logiRole");
    localStorage.removeItem("logiUser");
    window.location.href = "login.html";
  }

  async function apiFetch(path, options = {}) {
    const headers = new Headers(options.headers || {});
    if (!headers.has("Content-Type") && options.body) headers.set("Content-Type", "application/json");
    const jwt = token();
    if (jwt) headers.set("Authorization", `Bearer ${jwt}`);
    const response = await fetch(`${API_BASE}${path}`, { ...options, headers });
    if (response.status === 401) {
      logout();
      throw new Error("Your session has expired. Please sign in again.");
    }
    const text = await response.text();
    let body = null;
    try { body = text ? JSON.parse(text) : null; } catch (_) { body = text; }
    if (!response.ok) throw new Error(body?.message || body?.detail || `Request failed (${response.status})`);
    return body;
  }

  window.logiApi = { apiFetch, logout, token };

  const publicPage = ["", "index.html", "login.html"].includes(location.pathname.split("/").pop());
  if (!publicPage && !token()) window.location.href = "login.html";
})();
