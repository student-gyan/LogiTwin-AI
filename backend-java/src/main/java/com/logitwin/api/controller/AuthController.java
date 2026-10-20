package com.logitwin.api.controller;

import com.logitwin.api.dto.ApiDtos.LoginRequest;
import com.logitwin.api.dto.ApiDtos.LoginResponse;
import com.logitwin.api.service.AuthService;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
  private final AuthService authService;

  public AuthController(AuthService authService) {
    this.authService = authService;
  }

  @PostMapping("/login")
  public LoginResponse login(@Valid @RequestBody LoginRequest request) {
    return authService.login(request);
  }

  @GetMapping("/me")
  public Map<String, Object> me(Authentication authentication) {
    return Map.of("email", authentication.getName(), "roles",
        authentication.getAuthorities());
  }
}
