package com.logitwin.api.service;

import com.logitwin.api.config.SecurityConfig.JwtService;
import com.logitwin.api.dto.ApiDtos.LoginRequest;
import com.logitwin.api.dto.ApiDtos.LoginResponse;
import java.util.Locale;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {
  private final JdbcTemplate jdbc;
  private final PasswordEncoder passwordEncoder;
  private final JwtService jwtService;

  public AuthService(
      JdbcTemplate jdbc, PasswordEncoder passwordEncoder, JwtService jwtService) {
    this.jdbc = jdbc;
    this.passwordEncoder = passwordEncoder;
    this.jwtService = jwtService;
  }

  public LoginResponse login(LoginRequest request) {
    List<Map<String, Object>> users = jdbc.queryForList(
        "SELECT name, email, password_hash, role FROM users "
            + "WHERE email = ? AND is_active = TRUE",
        request.email());
    if (users.isEmpty()) {
      throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,
          "Invalid email or password");
    }
    Map<String, Object> user = users.get(0);
    String actualRole = String.valueOf(user.get("role"));
    String requestedRole = request.role().toLowerCase(Locale.ROOT)
        .replace(" ", "_");
    if (!actualRole.equals(requestedRole)) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN,
          "The selected role does not match this account");
    }
    String hash = (String) user.get("password_hash");
    boolean validDemoPassword = hash == null && "demo".equals(request.password());
    boolean validPassword = validDemoPassword
        || (hash != null && passwordEncoder.matches(request.password(), hash));
    if (!validPassword) {
      throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,
          "Invalid email or password");
    }
    jdbc.update("UPDATE users SET last_signed_in = NOW() WHERE email = ?",
        request.email());
    String token = jwtService.createToken(request.email(), actualRole);
    return new LoginResponse(token, String.valueOf(user.get("name")),
        request.email(), actualRole);
  }
}
