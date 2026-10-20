
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
    const isLoginRequest = path === "/api/auth/login";

    if (!headers.has("Content-Type") && options.body) {
      headers.set("Content-Type", "application/json");
    }

    const jwt = token();

    // Never send an old token with a fresh login request.
    if (jwt && !isLoginRequest) {
      headers.set("Authorization", `Bearer ${jwt}`);
    } else {
      headers.delete("Authorization");
    }

    const response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers
    });

    const text = await response.text();
    let body = null;

    try {
      body = text ? JSON.parse(text) : null;
    } catch (_) {
      body = text;
    }

    if (response.status === 401 && !isLoginRequest) {
      logout();
      throw new Error("Your session has expired. Please sign in again.");
    }

    if (!response.ok) {
      throw new Error(
        body?.message ||
        body?.detail ||
        (isLoginRequest && response.status === 401
          ? "Invalid email or password."
          : `Request failed (${response.status})`)
      );
    }

    return body;
  }

  window.logiApi = { apiFetch, logout, token };

  const currentPage = location.pathname.split("/").pop();
  const publicPage = ["", "index.html", "login.html"].includes(currentPage);

  if (!publicPage && !token()) {
    window.location.href = "login.html";
  }
})();
