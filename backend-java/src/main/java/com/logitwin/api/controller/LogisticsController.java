package com.logitwin.api.controller;

import com.logitwin.api.dto.ApiDtos.CreateDisruptionRequest;
import com.logitwin.api.dto.ApiDtos.DashboardSummary;
import com.logitwin.api.dto.ApiDtos.DeliveryPrediction;
import com.logitwin.api.dto.ApiDtos.DeliveryPredictionRequest;
import com.logitwin.api.dto.ApiDtos.InventoryHealth;
import com.logitwin.api.dto.ApiDtos.ShipmentSummary;
import com.logitwin.api.service.LogisticsService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class LogisticsController {
  private final LogisticsService logisticsService;

  public LogisticsController(LogisticsService logisticsService) {
    this.logisticsService = logisticsService;
  }

  @GetMapping("/dashboard/summary")
  public DashboardSummary dashboard() {
    return logisticsService.dashboard();
  }

  @GetMapping("/shipments/priority")
  public List<ShipmentSummary> priorityShipments() {
    return logisticsService.priorityShipments();
  }

  @GetMapping("/inventory/health")
  public List<InventoryHealth> inventoryHealth() {
    return logisticsService.inventoryHealth();
  }

  @PostMapping("/delivery/predict")
  public DeliveryPrediction predict(
      @Valid @RequestBody DeliveryPredictionRequest request) {
    return logisticsService.predict(request);
  }

  @PostMapping("/disruptions")
  @PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
  public Map<String, Object> createDisruption(
      @Valid @RequestBody CreateDisruptionRequest request,
      Authentication authentication) {
    long id = logisticsService.createDisruption(request, authentication.getName());
    return Map.of("id", id, "status", "active");
  }

  @GetMapping("/health")
  public Map<String, String> health() {
    return Map.of("status", "ok", "service", "logi-twin-api");
  }

  @GetMapping("/shipments/{shipmentCode}")
  public ShipmentSummary shipment(@PathVariable String shipmentCode) {
    try {
      return logisticsService.shipmentByCode(shipmentCode);
    } catch (org.springframework.dao.EmptyResultDataAccessException error) {
      throw new org.springframework.web.server.ResponseStatusException(
          org.springframework.http.HttpStatus.NOT_FOUND, "Shipment not found");
    }
  }
}
