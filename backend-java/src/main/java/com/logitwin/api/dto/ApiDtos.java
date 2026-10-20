package com.logitwin.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;
import java.util.List;

public final class ApiDtos {
  private ApiDtos() { }

  public record LoginRequest(
      @Email @NotBlank String email,
      @NotBlank String password,
      @NotBlank String role) { }

  public record LoginResponse(
      String token,
      String name,
      String email,
      String role) { }

  public record ShipmentSummary(
      String shipmentCode,
      String itemCategory,
      String priority,
      String originCity,
      String destinationCity,
      String status,
      String routeName,
      LocalDateTime predictedDeliveryAt,
      Double confidencePercent,
      Double disruptionDelayHours) { }

  public record DeliveryPredictionRequest(
      @NotNull Long shipmentId) { }

  public record DeliveryPrediction(
      Long shipmentId,
      String shipmentCode,
      LocalDateTime predictedDeliveryAt,
      Double transitHours,
      Double disruptionDelayHours,
      Double confidencePercent,
      String routeName,
      String evidence) { }

  public record InventoryHealth(
      Long id,
      String sku,
      String itemName,
      String city,
      Integer availableUnits,
      Integer reservedUnits,
      Integer inTransitUnits,
      Integer safetyStockUnits,
      Double daysCover,
      String healthStatus) { }

  public record DashboardSummary(
      long activeShipments,
      long atRiskShipments,
      long inventoryItemsAtRisk,
      long activeDisruptions,
      List<ShipmentSummary> priorityShipments) { }

  public record CreateDisruptionRequest(
      @NotBlank String title,
      @NotBlank String disruptionType,
      @NotBlank String severity,
      Long affectedHubId,
      Long affectedRouteId,
      @NotNull LocalDateTime startsAt,
      LocalDateTime endsAt,
      double delayHours,
      int affectedOrders,
      String description) { }
}
