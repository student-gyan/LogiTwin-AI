package com.logitwin.api.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.logitwin.api.dto.ApiDtos.CreateDisruptionRequest;
import com.logitwin.api.dto.ApiDtos.DashboardSummary;
import com.logitwin.api.dto.ApiDtos.DeliveryPrediction;
import com.logitwin.api.dto.ApiDtos.DeliveryPredictionRequest;
import com.logitwin.api.dto.ApiDtos.InventoryHealth;
import com.logitwin.api.dto.ApiDtos.ShipmentSummary;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LogisticsService {
  private final JdbcTemplate jdbc;
  private final ObjectMapper mapper;

  public LogisticsService(JdbcTemplate jdbc, ObjectMapper mapper) {
    this.jdbc = jdbc;
    this.mapper = mapper;
  }

  public DashboardSummary dashboard() {
    long active = count("SELECT COUNT(*) FROM shipments "
        + "WHERE status IN ('planned', 'in_transit', 'delayed')");
    long atRisk = count("SELECT COUNT(*) FROM shipments "
        + "WHERE status = 'delayed' OR priority = 'critical'");
    long inventoryRisk = count("SELECT COUNT(*) FROM inventory_items "
        + "WHERE available_units <= safety_stock_units");
    long disruptions = count("SELECT COUNT(*) FROM disruptions WHERE status = 'active'");
    return new DashboardSummary(active, atRisk, inventoryRisk, disruptions,
        priorityShipments());
  }

  public List<ShipmentSummary> priorityShipments() {
    String sql = "SELECT shipment_code, item_category, priority, origin_city, "
        + "destination_city, status, route_name, predicted_delivery_at, "
        + "confidence_percent, disruption_delay_hours FROM v_active_shipments "
        + "ORDER BY FIELD(priority, 'critical', 'high', 'standard'), "
        + "predicted_delivery_at LIMIT 50";
    return jdbc.query(sql, (rs, row) -> new ShipmentSummary(
        rs.getString("shipment_code"), rs.getString("item_category"),
        rs.getString("priority"), rs.getString("origin_city"),
        rs.getString("destination_city"), rs.getString("status"),
        rs.getString("route_name"), toLocalDateTime(rs.getTimestamp("predicted_delivery_at")),
        rs.getObject("confidence_percent", Double.class),
        rs.getObject("disruption_delay_hours", Double.class)));
  }

  public List<InventoryHealth> inventoryHealth() {
    String sql = "SELECT id, sku, item_name, city, available_units, reserved_units, "
        + "in_transit_units, safety_stock_units, days_cover, health_status "
        + "FROM v_inventory_health ORDER BY FIELD(health_status, "
        + "'critical', 'watch', 'healthy'), days_cover";
    return jdbc.query(sql, (rs, row) -> new InventoryHealth(
        rs.getLong("id"), rs.getString("sku"), rs.getString("item_name"),
        rs.getString("city"), rs.getInt("available_units"),
        rs.getInt("reserved_units"), rs.getInt("in_transit_units"),
        rs.getInt("safety_stock_units"), rs.getObject("days_cover", Double.class),
        rs.getString("health_status")));
  }

  public ShipmentSummary shipmentByCode(String shipmentCode) {
    String sql = "SELECT shipment_code, item_category, priority, origin_city, "
        + "destination_city, status, route_name, predicted_delivery_at, "
        + "confidence_percent, disruption_delay_hours FROM v_active_shipments "
        + "WHERE shipment_code = ?";
    return jdbc.queryForObject(sql, (rs, row) -> new ShipmentSummary(
        rs.getString("shipment_code"), rs.getString("item_category"),
        rs.getString("priority"), rs.getString("origin_city"),
        rs.getString("destination_city"), rs.getString("status"),
        rs.getString("route_name"), toLocalDateTime(rs.getTimestamp("predicted_delivery_at")),
        rs.getObject("confidence_percent", Double.class),
        rs.getObject("disruption_delay_hours", Double.class)), shipmentCode);
  }

  @Transactional
  public DeliveryPrediction predict(DeliveryPredictionRequest request) {
    Map<String, Object> shipment = jdbc.queryForMap(
        "SELECT s.id, s.shipment_code, s.dispatch_at, s.selected_route_id, "
            + "r.route_name, r.normal_transit_hours + r.buffer_hours AS transit_hours, "
            + "r.reliability_score FROM shipments s JOIN routes r "
            + "ON r.id = s.selected_route_id WHERE s.id = ?", request.shipmentId());
    long routeId = ((Number) shipment.get("selected_route_id")).longValue();
    LocalDateTime dispatch = toLocalDateTime((Timestamp) shipment.get("dispatch_at"));
    double transit = ((Number) shipment.get("transit_hours")).doubleValue();
    double delay = jdbc.queryForObject(
        "SELECT COALESCE(SUM(d.delay_hours), 0) FROM disruptions d "
            + "JOIN shipments s ON s.id = ? "
            + "WHERE d.status = 'active' AND d.starts_at <= DATE_ADD(?, INTERVAL 30 DAY) "
            + "AND (d.ends_at IS NULL OR d.ends_at >= ?) "
            + "AND (d.affected_route_id = s.selected_route_id "
            + "OR d.affected_hub_id IN (s.origin_hub_id, s.destination_hub_id))", Double.class,
        request.shipmentId(), Timestamp.valueOf(dispatch), Timestamp.valueOf(dispatch));
    double reliability = ((Number) shipment.get("reliability_score")).doubleValue();
    double confidence = Math.max(50.0, Math.min(99.9, reliability - delay * 0.4));
    LocalDateTime exactDate = dispatch.plusHours((long) Math.ceil(transit + delay));
    int nextVersion = jdbc.queryForObject(
        "SELECT COALESCE(MAX(prediction_version), 0) + 1 FROM delivery_predictions "
            + "WHERE shipment_id = ?", Integer.class, request.shipmentId());
    jdbc.update("UPDATE delivery_predictions SET prediction_status = 'superseded' "
        + "WHERE shipment_id = ? AND prediction_status = 'active'", request.shipmentId());
    String evidence = json(Map.of("route_hours", transit, "disruption_hours", delay,
        "calculation", "route transit plus active disruption delay"));
    jdbc.update("INSERT INTO delivery_predictions (shipment_id, route_id, "
        + "prediction_version, predicted_delivery_at, predicted_transit_hours, "
        + "disruption_delay_hours, confidence_percent, prediction_status, route_evidence) "
        + "VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?)", request.shipmentId(), routeId,
        nextVersion, Timestamp.valueOf(exactDate), transit, delay, confidence, evidence);
    return new DeliveryPrediction(request.shipmentId(),
        String.valueOf(shipment.get("shipment_code")), exactDate, transit, delay,
        confidence, String.valueOf(shipment.get("route_name")), evidence);
  }

  @Transactional
  public long createDisruption(CreateDisruptionRequest request, String email) {
    Long userId = jdbc.queryForObject("SELECT id FROM users WHERE email = ?",
        Long.class, email);
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.update(connection -> {
      var statement = connection.prepareStatement(
          "INSERT INTO disruptions (title, disruption_type, severity, "
              + "affected_hub_id, affected_route_id, starts_at, ends_at, "
              + "delay_hours, affected_orders, description, status, created_by) "
              + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?)",
          java.sql.Statement.RETURN_GENERATED_KEYS);
      statement.setString(1, request.title());
      statement.setString(2, request.disruptionType());
      statement.setString(3, request.severity());
      statement.setObject(4, request.affectedHubId());
      statement.setObject(5, request.affectedRouteId());
      statement.setTimestamp(6, Timestamp.valueOf(request.startsAt()));
      statement.setTimestamp(7, request.endsAt() == null ? null
          : Timestamp.valueOf(request.endsAt()));
      statement.setDouble(8, request.delayHours());
      statement.setInt(9, request.affectedOrders());
      statement.setString(10, request.description());
      statement.setObject(11, userId);
      return statement;
    }, keys);
    return keys.getKey() == null ? 0L : keys.getKey().longValue();
  }

  private long count(String sql) {
    Long value = jdbc.queryForObject(sql, Long.class);
    return value == null ? 0 : value;
  }

  private String json(Object value) {
    try {
      return mapper.writeValueAsString(value);
    } catch (JsonProcessingException error) {
      return "{}";
    }
  }

  private LocalDateTime toLocalDateTime(Timestamp value) {
    return value == null ? null : value.toLocalDateTime();
  }
}
