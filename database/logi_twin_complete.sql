cd backend-javacd backend-java-- Logi Twin AI complete MySQL database
-- MySQL 8.0+
-- Covers users, roles, hubs, routes, shipments, disruptions,
-- inventory, demand forecasts, exact delivery predictions,
-- reports, notifications, and audit history.

CREATE DATABASE IF NOT EXISTS logi_twin_ai
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE logi_twin_ai;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS v_delivery_prediction_dashboard;
DROP VIEW IF EXISTS v_inventory_health;
DROP VIEW IF EXISTS v_active_shipments;

DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS delivery_predictions;
DROP TABLE IF EXISTS demand_forecasts;
DROP TABLE IF EXISTS inventory_movements;
DROP TABLE IF EXISTS inventory_items;
DROP TABLE IF EXISTS shipment_events;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS disruptions;
DROP TABLE IF EXISTS route_options;
DROP TABLE IF EXISTS routes;
DROP TABLE IF EXISTS hubs;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  openId VARCHAR(64) NULL,
  name VARCHAR(160) NOT NULL,
  email VARCHAR(320) NOT NULL,
  password_hash VARCHAR(255) NULL,
  role ENUM('user', 'admin', 'manager', 'delivery_driver', 'analyst')
    NOT NULL DEFAULT 'user',
  phone VARCHAR(40) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_signed_in DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_open_id (openId),
  KEY idx_users_role_active (role, is_active)
) ENGINE = InnoDB;

CREATE TABLE hubs (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(120) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100) NULL,
  country VARCHAR(80) NOT NULL DEFAULT 'India',
  latitude DECIMAL(10, 7) NULL,
  longitude DECIMAL(10, 7) NULL,
  hub_type ENUM('port', 'warehouse', 'distribution_center', 'cross_dock')
    NOT NULL DEFAULT 'warehouse',
  daily_capacity_units INT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_hubs_code (code),
  KEY idx_hubs_city (city),
  KEY idx_hubs_type_active (hub_type, is_active)
) ENGINE = InnoDB;

CREATE TABLE routes (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  route_code VARCHAR(40) NOT NULL,
  origin_hub_id INT UNSIGNED NOT NULL,
  destination_hub_id INT UNSIGNED NOT NULL,
  route_name VARCHAR(180) NOT NULL,
  transport_mode ENUM('road', 'rail', 'air', 'sea', 'multimodal')
    NOT NULL DEFAULT 'road',
  distance_km DECIMAL(10, 2) NOT NULL DEFAULT 0,
  normal_transit_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,
  buffer_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,
  cost_per_unit DECIMAL(12, 2) NOT NULL DEFAULT 0,
  capacity_units INT UNSIGNED NOT NULL DEFAULT 0,
  reliability_score DECIMAL(5, 2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_routes_code (route_code),
  KEY idx_routes_origin_destination (origin_hub_id, destination_hub_id),
  CONSTRAINT fk_routes_origin FOREIGN KEY (origin_hub_id) REFERENCES hubs(id),
  CONSTRAINT fk_routes_destination FOREIGN KEY (destination_hub_id)
    REFERENCES hubs(id),
  CONSTRAINT chk_routes_reliability CHECK (reliability_score BETWEEN 0 AND 100)
) ENGINE = InnoDB;

CREATE TABLE route_options (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_id BIGINT UNSIGNED NULL,
  route_id INT UNSIGNED NOT NULL,
  option_rank TINYINT UNSIGNED NOT NULL DEFAULT 1,
  scenario_name VARCHAR(120) NOT NULL,
  estimated_delay_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,
  estimated_cost DECIMAL(14, 2) NOT NULL DEFAULT 0,
  protected_units INT UNSIGNED NOT NULL DEFAULT 0,
  loss_score DECIMAL(12, 4) NOT NULL DEFAULT 0,
  recommendation_status ENUM('candidate', 'recommended', 'approved', 'rejected')
    NOT NULL DEFAULT 'candidate',
  calculated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_route_options_shipment (shipment_id),
  KEY idx_route_options_status (recommendation_status),
  CONSTRAINT fk_route_options_route FOREIGN KEY (route_id) REFERENCES routes(id)
) ENGINE = InnoDB;

CREATE TABLE disruptions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(180) NOT NULL,
  disruption_type ENUM('port_closure', 'road_closure', 'weather', 'capacity',
    'labor', 'security', 'other') NOT NULL DEFAULT 'other',
  severity ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
  affected_hub_id INT UNSIGNED NULL,
  affected_route_id INT UNSIGNED NULL,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NULL,
  delay_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,
  affected_orders INT UNSIGNED NOT NULL DEFAULT 0,
  description TEXT NULL,
  status ENUM('draft', 'active', 'resolved', 'cancelled')
    NOT NULL DEFAULT 'active',
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_disruptions_status_window (status, starts_at, ends_at),
  KEY idx_disruptions_hub (affected_hub_id),
  CONSTRAINT fk_disruptions_hub FOREIGN KEY (affected_hub_id) REFERENCES hubs(id),
  CONSTRAINT fk_disruptions_route FOREIGN KEY (affected_route_id)
    REFERENCES routes(id),
  CONSTRAINT fk_disruptions_user FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE = InnoDB;

CREATE TABLE shipments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_code VARCHAR(40) NOT NULL,
  order_reference VARCHAR(80) NULL,
  origin_hub_id INT UNSIGNED NOT NULL,
  destination_hub_id INT UNSIGNED NOT NULL,
  selected_route_id INT UNSIGNED NULL,
  assigned_driver_id INT UNSIGNED NULL,
  item_category VARCHAR(100) NOT NULL,
  priority ENUM('standard', 'high', 'critical') NOT NULL DEFAULT 'standard',
  units INT UNSIGNED NOT NULL DEFAULT 0,
  weight_kg DECIMAL(12, 2) NOT NULL DEFAULT 0,
  dispatch_at DATETIME NOT NULL,
  promised_delivery_at DATETIME NULL,
  actual_delivery_at DATETIME NULL,
  status ENUM('planned', 'in_transit', 'delayed', 'delivered', 'cancelled')
    NOT NULL DEFAULT 'planned',
  current_city VARCHAR(100) NULL,
  customer_name VARCHAR(160) NULL,
  customer_phone VARCHAR(40) NULL,
  notes TEXT NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_shipments_code (shipment_code),
  KEY idx_shipments_status (status),
  KEY idx_shipments_destination (destination_hub_id),
  KEY idx_shipments_dispatch (dispatch_at),
  KEY idx_shipments_driver (assigned_driver_id),
  CONSTRAINT fk_shipments_origin FOREIGN KEY (origin_hub_id) REFERENCES hubs(id),
  CONSTRAINT fk_shipments_destination FOREIGN KEY (destination_hub_id)
    REFERENCES hubs(id),
  CONSTRAINT fk_shipments_route FOREIGN KEY (selected_route_id)
    REFERENCES routes(id),
  CONSTRAINT fk_shipments_driver FOREIGN KEY (assigned_driver_id)
    REFERENCES users(id),
  CONSTRAINT fk_shipments_creator FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE = InnoDB;

ALTER TABLE route_options
  ADD CONSTRAINT fk_route_options_shipment FOREIGN KEY (shipment_id)
  REFERENCES shipments(id) ON DELETE CASCADE;

CREATE TABLE shipment_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_id BIGINT UNSIGNED NOT NULL,
  event_type ENUM('created', 'picked_up', 'at_hub', 'departed', 'delayed',
    'rerouted', 'out_for_delivery', 'delivered', 'exception') NOT NULL,
  event_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  city VARCHAR(100) NULL,
  latitude DECIMAL(10, 7) NULL,
  longitude DECIMAL(10, 7) NULL,
  message VARCHAR(255) NULL,
  created_by INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_events_shipment_time (shipment_id, event_time),
  CONSTRAINT fk_events_shipment FOREIGN KEY (shipment_id)
    REFERENCES shipments(id) ON DELETE CASCADE,
  CONSTRAINT fk_events_user FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE = InnoDB;

CREATE TABLE inventory_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sku VARCHAR(60) NOT NULL,
  item_name VARCHAR(180) NOT NULL,
  category VARCHAR(100) NULL,
  unit VARCHAR(30) NOT NULL DEFAULT 'units',
  hub_id INT UNSIGNED NOT NULL,
  available_units INT UNSIGNED NOT NULL DEFAULT 0,
  reserved_units INT UNSIGNED NOT NULL DEFAULT 0,
  in_transit_units INT UNSIGNED NOT NULL DEFAULT 0,
  safety_stock_units INT UNSIGNED NOT NULL DEFAULT 0,
  reorder_point_units INT UNSIGNED NOT NULL DEFAULT 0,
  average_daily_demand DECIMAL(12, 2) NOT NULL DEFAULT 0,
  lead_time_days DECIMAL(8, 2) NOT NULL DEFAULT 0,
  last_updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_inventory_sku_hub (sku, hub_id),
  KEY idx_inventory_hub_risk (hub_id, available_units, safety_stock_units),
  CONSTRAINT fk_inventory_hub FOREIGN KEY (hub_id) REFERENCES hubs(id)
) ENGINE = InnoDB;

CREATE TABLE inventory_movements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  inventory_item_id BIGINT UNSIGNED NOT NULL,
  shipment_id BIGINT UNSIGNED NULL,
  movement_type ENUM('receipt', 'allocation', 'dispatch', 'adjustment', 'return')
    NOT NULL,
  quantity INT NOT NULL,
  reference_code VARCHAR(80) NULL,
  movement_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes VARCHAR(255) NULL,
  created_by INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_movements_item_time (inventory_item_id, movement_at),
  CONSTRAINT fk_movements_item FOREIGN KEY (inventory_item_id)
    REFERENCES inventory_items(id),
  CONSTRAINT fk_movements_shipment FOREIGN KEY (shipment_id)
    REFERENCES shipments(id),
  CONSTRAINT fk_movements_user FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE = InnoDB;

CREATE TABLE demand_forecasts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  inventory_item_id BIGINT UNSIGNED NOT NULL,
  hub_id INT UNSIGNED NOT NULL,
  forecast_date DATE NOT NULL,
  predicted_units DECIMAL(12, 2) NOT NULL DEFAULT 0,
  lower_bound_units DECIMAL(12, 2) NULL,
  upper_bound_units DECIMAL(12, 2) NULL,
  demand_change_percent DECIMAL(8, 2) NOT NULL DEFAULT 0,
  confidence_percent DECIMAL(5, 2) NOT NULL DEFAULT 0,
  model_version VARCHAR(60) NOT NULL DEFAULT 'logi-twin-v1',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_demand_item_hub_date (inventory_item_id, hub_id, forecast_date),
  KEY idx_demand_hub_date (hub_id, forecast_date),
  CONSTRAINT fk_demand_item FOREIGN KEY (inventory_item_id)
    REFERENCES inventory_items(id),
  CONSTRAINT fk_demand_hub FOREIGN KEY (hub_id) REFERENCES hubs(id)
) ENGINE = InnoDB;

CREATE TABLE delivery_predictions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_id BIGINT UNSIGNED NOT NULL,
  route_id INT UNSIGNED NOT NULL,
  prediction_version INT UNSIGNED NOT NULL DEFAULT 1,
  predicted_delivery_at DATETIME NOT NULL,
  predicted_transit_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,
  disruption_delay_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,
  confidence_percent DECIMAL(5, 2) NOT NULL DEFAULT 0,
  prediction_status ENUM('active', 'superseded', 'confirmed', 'missed')
    NOT NULL DEFAULT 'active',
  route_evidence JSON NULL,
  predicted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by INT UNSIGNED NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_prediction_version (shipment_id, prediction_version),
  KEY idx_prediction_active (shipment_id, prediction_status),
  KEY idx_prediction_date (predicted_delivery_at),
  CONSTRAINT fk_predictions_shipment FOREIGN KEY (shipment_id)
    REFERENCES shipments(id) ON DELETE CASCADE,
  CONSTRAINT fk_predictions_route FOREIGN KEY (route_id) REFERENCES routes(id),
  CONSTRAINT fk_predictions_user FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE = InnoDB;

CREATE TABLE reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  report_code VARCHAR(60) NOT NULL,
  report_type ENUM('disruption', 'route', 'demand', 'inventory', 'delivery',
    'executive') NOT NULL,
  title VARCHAR(200) NOT NULL,
  status ENUM('processing', 'ready', 'failed') NOT NULL DEFAULT 'processing',
  file_url VARCHAR(500) NULL,
  filters JSON NULL,
  generated_by INT UNSIGNED NULL,
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_reports_code (report_code),
  KEY idx_reports_type_status (report_type, status),
  CONSTRAINT fk_reports_user FOREIGN KEY (generated_by) REFERENCES users(id)
) ENGINE = InnoDB;

CREATE TABLE notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  notification_type ENUM('disruption', 'delivery', 'inventory', 'demand', 'system')
    NOT NULL,
  title VARCHAR(180) NOT NULL,
  message TEXT NOT NULL,
  related_shipment_id BIGINT UNSIGNED NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_notifications_user_read (user_id, is_read, created_at),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_notifications_shipment FOREIGN KEY (related_shipment_id)
    REFERENCES shipments(id)
) ENGINE = InnoDB;

CREATE TABLE audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NULL,
  action_name VARCHAR(100) NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id VARCHAR(80) NULL,
  old_values JSON NULL,
  new_values JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_entity (entity_type, entity_id),
  KEY idx_audit_user_time (user_id, created_at),
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE = InnoDB;

CREATE OR REPLACE VIEW v_active_shipments AS
SELECT
  s.id,
  s.shipment_code,
  s.item_category,
  s.priority,
  s.units,
  s.status,
  s.current_city,
  oh.city AS origin_city,
  dh.city AS destination_city,
  r.route_name,
  r.transport_mode,
  p.predicted_delivery_at,
  p.confidence_percent,
  p.disruption_delay_hours
FROM shipments s
JOIN hubs oh ON oh.id = s.origin_hub_id
JOIN hubs dh ON dh.id = s.destination_hub_id
LEFT JOIN routes r ON r.id = s.selected_route_id
LEFT JOIN delivery_predictions p
  ON p.shipment_id = s.id AND p.prediction_status = 'active'
WHERE s.status IN ('planned', 'in_transit', 'delayed');

CREATE OR REPLACE VIEW v_inventory_health AS
SELECT
  i.id,
  i.sku,
  i.item_name,
  i.hub_id,
  h.city,
  i.available_units,
  i.reserved_units,
  i.in_transit_units,
  i.safety_stock_units,
  i.reorder_point_units,
  i.average_daily_demand,
  ROUND(
    i.available_units / NULLIF(i.average_daily_demand, 0), 1
  ) AS days_cover,
  CASE
    WHEN i.available_units <= i.reorder_point_units THEN 'critical'
    WHEN i.available_units <= i.safety_stock_units THEN 'watch'
    ELSE 'healthy'
  END AS health_status
FROM inventory_items i
JOIN hubs h ON h.id = i.hub_id;

CREATE OR REPLACE VIEW v_delivery_prediction_dashboard AS
SELECT
  s.shipment_code,
  s.item_category,
  s.priority,
  oh.city AS origin_city,
  dh.city AS destination_city,
  p.predicted_delivery_at AS exact_delivery_date,
  p.predicted_transit_hours,
  p.disruption_delay_hours,
  p.confidence_percent,
  r.route_name,
  p.prediction_status
FROM delivery_predictions p
JOIN shipments s ON s.id = p.shipment_id
JOIN routes r ON r.id = p.route_id
JOIN hubs oh ON oh.id = s.origin_hub_id
JOIN hubs dh ON dh.id = s.destination_hub_id
WHERE p.prediction_status = 'active';

DELIMITER $$

CREATE PROCEDURE sp_predict_delivery_date(IN p_shipment_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_route_id INT UNSIGNED;
  DECLARE v_dispatch DATETIME;
  DECLARE v_transit DECIMAL(8, 2);
  DECLARE v_delay DECIMAL(8, 2) DEFAULT 0;
  DECLARE v_confidence DECIMAL(5, 2);
  DECLARE v_next_version INT UNSIGNED;
  DECLARE v_delivery DATETIME;
  DECLARE v_evidence JSON;

  SELECT selected_route_id, dispatch_at
    INTO v_route_id, v_dispatch
    FROM shipments
   WHERE id = p_shipment_id;

  SELECT normal_transit_hours + buffer_hours, reliability_score
    INTO v_transit, v_confidence
    FROM routes
   WHERE id = v_route_id;

  SELECT COALESCE(SUM(d.delay_hours), 0)
    INTO v_delay
    FROM disruptions d
    JOIN shipments s ON s.id = p_shipment_id
   WHERE d.status = 'active'
     AND d.starts_at <= DATE_ADD(v_dispatch, INTERVAL 30 DAY)
     AND (d.ends_at IS NULL OR d.ends_at >= v_dispatch)
     AND (d.affected_route_id = v_route_id
       OR d.affected_hub_id IN (s.origin_hub_id, s.destination_hub_id));

  SET v_delivery = DATE_ADD(v_dispatch, INTERVAL CEIL(v_transit + v_delay) HOUR);
  SET v_confidence = LEAST(99.90, GREATEST(50.00, v_confidence - v_delay * 0.4));

  SELECT COALESCE(MAX(prediction_version), 0) + 1
    INTO v_next_version
    FROM delivery_predictions
   WHERE shipment_id = p_shipment_id;

  UPDATE delivery_predictions
     SET prediction_status = 'superseded'
   WHERE shipment_id = p_shipment_id
     AND prediction_status = 'active';

  SET v_evidence = JSON_OBJECT(
    'route_hours', v_transit,
    'disruption_hours', v_delay,
    'calculation', 'route transit plus active disruption delay'
  );

  INSERT INTO delivery_predictions (
    shipment_id, route_id, prediction_version, predicted_delivery_at,
    predicted_transit_hours, disruption_delay_hours, confidence_percent,
    prediction_status, route_evidence
  ) VALUES (
    p_shipment_id, v_route_id, v_next_version, v_delivery,
    v_transit, v_delay, v_confidence, 'active', v_evidence
  );

  SELECT *
    FROM delivery_predictions
   WHERE shipment_id = p_shipment_id
     AND prediction_version = v_next_version;
END$$

CREATE TRIGGER trg_shipment_delivery_audit
AFTER UPDATE ON shipments
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status OR OLD.current_city <> NEW.current_city THEN
    INSERT INTO audit_logs (
      action_name, entity_type, entity_id, old_values, new_values
    ) VALUES (
      'shipment_status_updated',
      'shipment',
      NEW.id,
      JSON_OBJECT('status', OLD.status, 'city', OLD.current_city),
      JSON_OBJECT('status', NEW.status, 'city', NEW.current_city)
    );
  END IF;
END$$

DELIMITER ;

INSERT INTO users (
  openId, name, email, password_hash, role, phone, last_signed_in
) VALUES
  ('admin-demo', 'Alex Morgan', 'admin@northstar.example', NULL, 'admin',
    '+91-9000000001', NOW()),
  ('manager-demo', 'Priya Shah', 'manager@northstar.example', NULL, 'manager',
    '+91-9000000002', NOW()),
  ('driver-demo', 'Ravi Kumar', 'driver@northstar.example', NULL,
    'delivery_driver', '+91-9000000003', NOW());

INSERT INTO hubs (
  code, name, city, state, latitude, longitude, hub_type, daily_capacity_units
) VALUES
  ('IN-MUM', 'Mumbai Port', 'Mumbai', 'Maharashtra', 18.9520, 72.9470,
    'port', 15000),
  ('IN-MUN', 'Mundra Alternate Hub', 'Mundra', 'Gujarat', 22.7360, 69.7040,
    'port', 12000),
  ('IN-PUN', 'Pune Distribution Center', 'Pune', 'Maharashtra', 18.5204, 73.8567,
    'distribution_center', 9000),
  ('IN-NCR', 'Delhi NCR Distribution Center', 'Delhi NCR', 'Delhi', 28.6139,
    77.2090, 'distribution_center', 15000),
  ('IN-BLR', 'Bengaluru Distribution Center', 'Bengaluru', 'Karnataka', 12.9716,
    77.5946, 'distribution_center', 11000),
  ('IN-HYD', 'Hyderabad Distribution Center', 'Hyderabad', 'Telangana', 17.3850,
    78.4867, 'distribution_center', 8000);

INSERT INTO routes (
  route_code, origin_hub_id, destination_hub_id, route_name, transport_mode,
  distance_km, normal_transit_hours, buffer_hours, cost_per_unit,
  capacity_units, reliability_score
) VALUES
  ('MUN-NCR-RAIL', 2, 4, 'Mundra to Delhi NCR via rail', 'multimodal',
    1050, 72, 12, 3.80, 9000, 94.00),
  ('MUN-PUN-ROAD', 2, 3, 'Mundra to Pune via NH48', 'road',
    820, 48, 10, 2.90, 7000, 88.00),
  ('MUN-BLR-RAIL', 2, 5, 'Mundra to Bengaluru via rail', 'multimodal',
    1500, 92, 16, 4.20, 6000, 86.00),
  ('MUM-PUN-ROAD', 1, 3, 'Mumbai to Pune direct road', 'road',
    150, 7, 3, 1.10, 6000, 82.00),
  ('MUM-NCR-ROAD', 1, 4, 'Mumbai to Delhi NCR direct road', 'road',
    1400, 54, 14, 3.50, 5000, 73.00);

INSERT INTO disruptions (
  title, disruption_type, severity, affected_hub_id, starts_at, ends_at,
  delay_hours, affected_orders, description, status, created_by
) VALUES (
  'Mumbai port closed for 48 hours', 'port_closure', 'critical', 1,
  '2026-09-22 00:00:00', '2026-09-24 00:00:00', 48, 5420,
  'Inbound port operations are suspended. Divert priority loads through Mundra.',
  'active', 1
);

INSERT INTO inventory_items (
  sku, item_name, category, hub_id, available_units, reserved_units,
  in_transit_units, safety_stock_units, reorder_point_units,
  average_daily_demand, lead_time_days
) VALUES
  ('MED-INS-001', 'Insulin pens', 'Medical devices', 4, 2460, 340, 2600,
    7500, 5200, 425.00, 4.50),
  ('BAT-LTH-002', 'Lithium cells', 'Energy', 5, 5820, 620, 3400,
    6100, 4300, 632.60, 6.00),
  ('CCK-003', 'Cold-chain kits', 'Healthcare', 3, 4180, 410, 1800,
    4400, 3200, 312.00, 5.00),
  ('IND-PAR-004', 'Industrial parts', 'Industrial', 6, 1920, 170, 2100,
    3900, 2700, 300.00, 4.00);

INSERT INTO demand_forecasts (
  inventory_item_id, hub_id, forecast_date, predicted_units,
  lower_bound_units, upper_bound_units, demand_change_percent,
  confidence_percent
) VALUES
  (1, 4, '2026-09-23', 610, 560, 680, 42.00, 93.00),
  (1, 4, '2026-09-24', 625, 570, 700, 44.00, 92.00),
  (2, 5, '2026-09-23', 810, 750, 890, 28.00, 89.00),
  (3, 3, '2026-09-23', 360, 330, 400, 19.00, 91.00),
  (4, 6, '2026-09-23', 340, 300, 390, 31.00, 87.00);

INSERT INTO shipments (
  shipment_code, order_reference, origin_hub_id, destination_hub_id,
  selected_route_id, assigned_driver_id, item_category, priority, units,
  weight_kg, dispatch_at, promised_delivery_at, status, current_city,
  customer_name, created_by
) VALUES
  ('LT-20481', 'ORD-DEL-20481', 1, 4, 1, 3, 'Medical devices', 'critical',
    1800, 920.00, '2026-09-22 06:00:00', '2026-09-26 18:00:00',
    'in_transit', 'Mundra', 'Delhi Health Network', 1),
  ('LT-20492', 'ORD-BLR-20492', 1, 5, 3, 3, 'Consumer electronics', 'high',
    1200, 740.00, '2026-09-22 08:00:00', '2026-09-28 12:00:00',
    'delayed', 'Mumbai', 'Bengaluru Retail Group', 2),
  ('LT-20504', 'ORD-HYD-20504', 1, 6, 1, 3, 'Cold-chain kits', 'critical',
    900, 480.00, '2026-09-22 10:00:00', '2026-09-27 09:30:00',
    'in_transit', 'Mundra', 'Hyderabad Care Systems', 1);

INSERT INTO delivery_predictions (
  shipment_id, route_id, prediction_version, predicted_delivery_at,
  predicted_transit_hours, disruption_delay_hours, confidence_percent,
  prediction_status, route_evidence, created_by
) VALUES
  (1, 1, 1, '2026-09-26 18:00:00', 84, 48, 93.80, 'active',
    JSON_OBJECT('route', 'Mundra + rail', 'inventory_check', 'passed',
      'capacity_check', 'passed', 'disruption_included', TRUE), 1),
  (2, 3, 1, '2026-09-28 12:00:00', 108, 48, 89.40, 'active',
    JSON_OBJECT('route', 'Mundra + rail', 'inventory_check', 'passed',
      'capacity_check', 'watch', 'disruption_included', TRUE), 1),
  (3, 1, 1, '2026-09-27 09:30:00', 95, 48, 91.10, 'active',
    JSON_OBJECT('route', 'Mundra + rail', 'inventory_check', 'passed',
      'capacity_check', 'passed', 'disruption_included', TRUE), 1);

INSERT INTO reports (
  report_code, report_type, title, status, filters, generated_by
) VALUES
  ('RPT-MUM-001', 'disruption', 'Mumbai closure impact report', 'ready',
    JSON_OBJECT('disruption_id', 1), 1),
  ('RPT-INV-001', 'inventory', 'Inventory health and reorder report', 'ready',
    JSON_OBJECT('cities', JSON_ARRAY('Delhi NCR', 'Pune', 'Bengaluru')), 2),
  ('RPT-DLV-001', 'delivery', 'Exact delivery date predictions', 'ready',
    JSON_OBJECT('prediction_status', 'active'), 1);

INSERT INTO notifications (
  user_id, notification_type, title, message, related_shipment_id
) VALUES
  (1, 'disruption', 'Mumbai port closure active',
    '48-hour closure is affecting inland road routes.', NULL),
  (2, 'inventory', 'Insulin pens below safety stock',
    'Delhi NCR has 5.8 days of cover. Reserve Mundra inbound units.', NULL),
  (3, 'delivery', 'New priority delivery route',
    'Shipment LT-20481 is assigned to the Mundra + rail route.', 1);

-- Useful first queries after importing the database:
-- SELECT * FROM v_active_shipments;
-- SELECT * FROM v_inventory_health ORDER BY health_status, days_cover;
-- SELECT * FROM v_delivery_prediction_dashboard;
-- CALL sp_predict_delivery_date(1);
