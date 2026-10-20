const roleButtons = document.querySelectorAll(".role-button");
const loginForm = document.querySelector("#login-form");
const submitButton = loginForm.querySelector("button[type=submit]");
let selectedRole = "Admin";

roleButtons.forEach(button => {
  button.addEventListener("click", () => {
    roleButtons.forEach(item => item.classList.remove("active"));
    button.classList.add("active");
    selectedRole = button.dataset.role;
    submitButton.textContent = `Continue as ${selectedRole} →`;
  });
});

loginForm.addEventListener("submit", event => {
  event.preventDefault();
  const email = document.querySelector("#email").value.trim();
  const password = document.querySelector("#password").value;
  submitButton.disabled = true;
  submitButton.textContent = "Signing in…";
  window.logiApi.apiFetch("/api/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password, role: selectedRole }),
  }).then(result => {
    localStorage.setItem("logiToken", result.token);
    localStorage.setItem("logiRole", result.role);
    localStorage.setItem("logiUser", result.email);
    window.location.href = result.role === "delivery_driver" ? "tracking.html" : "dashboard.html";
  }).catch(error => {
    submitButton.disabled = false;
    submitButton.textContent = `Continue as ${selectedRole} →`;
    alert(error.message);
  });
});
