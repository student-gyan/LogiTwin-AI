package com.logitwin.api.config;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Arrays;
import java.util.Date;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.OncePerRequestFilter;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {
  private final String secret;
  private final long expirationMinutes;
  private final String corsOrigins;

  public SecurityConfig(
      @Value("${logi-twin.jwt-secret}") String secret,
      @Value("${logi-twin.jwt-expiration-minutes}") long expirationMinutes,
      @Value("${logi-twin.cors-origins}") String corsOrigins) {
    this.secret = secret;
    this.expirationMinutes = expirationMinutes;
    this.corsOrigins = corsOrigins;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }

  @Bean
  public JwtService jwtService() {
    return new JwtService(secret, expirationMinutes);
  }

  @Bean
  public SecurityFilterChain securityFilterChain(
      HttpSecurity http, JwtAuthFilter jwtAuthFilter) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())
        .cors(cors -> { })
        .sessionManagement(session -> session
            .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers(
    "/",
    "/error",
    "/index.html",
    "/login.html",
    "/dashboard.html",
    "/tracking.html",
    "/routes.html",
    "/demand.html",
    "/delivery-predict.html",
    "/disruptions.html",
    "/inventory.html",
    "/reports.html",
    "/settings.html",
    "/css/**",
    "/js/**",
    "/images/**",
    "/api/auth/**",
    "/actuator/health"
).permitAll()
            .anyRequest().authenticated())
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
        .build();
  }

  @Bean
  public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(Arrays.stream(corsOrigins.split(","))
        .map(String::trim).filter(origin -> !origin.isBlank()).toList());
    config.setAllowedMethods(java.util.List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(java.util.List.of("*"));
    config.setAllowCredentials(true);
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
  }

  public static final class JwtService {
    private final Key key;
    private final long expirationMinutes;

    public JwtService(String secret, long expirationMinutes) {
      this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
      this.expirationMinutes = expirationMinutes;
    }

    public String createToken(String email, String role) {
      Date now = new Date();
      Date expiry = new Date(now.getTime() + expirationMinutes * 60_000);
      return Jwts.builder().subject(email).claim("role", role)
          .issuedAt(now).expiration(expiry).signWith(key).compact();
    }

    public Claims parse(String token) {
      return Jwts.parser().verifyWith((javax.crypto.SecretKey) key)
          .build().parseSignedClaims(token).getPayload();
    }
  }

  @Bean
  public JwtAuthFilter jwtAuthFilter(JwtService jwtService) {
    return new JwtAuthFilter(jwtService);
  }

  public static final class JwtAuthFilter extends OncePerRequestFilter {
    private final JwtService jwtService;

    public JwtAuthFilter(JwtService jwtService) {
      this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(
        HttpServletRequest request, HttpServletResponse response,
        FilterChain chain) throws ServletException, IOException {
      String header = request.getHeader("Authorization");
      if (header != null && header.startsWith("Bearer ")) {
        try {
          Claims claims = jwtService.parse(header.substring(7));
          String role = claims.get("role", String.class);
          var authority = new SimpleGrantedAuthority("ROLE_" + role.toUpperCase());
          var authentication = new UsernamePasswordAuthenticationToken(
              claims.getSubject(), null, java.util.List.of(authority));
          org.springframework.security.core.context.SecurityContextHolder
              .getContext().setAuthentication(authentication);
        } catch (RuntimeException ignored) {
          response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
          return;
        }
      }
      chain.doFilter(request, response);
    }
  }
}
