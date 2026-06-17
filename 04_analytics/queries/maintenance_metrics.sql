-- Phase 4: Maintenance & Health Queries
-- SQL queries aligned with SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE schema
-- ============================================================================

-- ============================================
-- QUERY 1: Critical and Warning Alerts (Immediate Action)
-- ============================================
-- Business question: Which equipment needs immediate maintenance today?
-- Grain: One row per equipment per alert day

SELECT 
    event_date,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    risk_level,
    min_health_score as lowest_health,
    recommended_action
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE risk_level IN ('CRITICAL', 'WARNING')
ORDER BY event_date DESC, risk_level DESC;


-- ============================================
-- QUERY 2: Daily Equipment Health Trend
-- ============================================
-- Business question: What is the health degradation trajectory for each unit?
-- Grain: One row per day per equipment

SELECT 
    event_date,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    avg_health_score,
    min_health_score
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE event_date >= DATEADD(day, -7, CURRENT_DATE)
ORDER BY EQUIPMENT_ID, event_date;


-- ============================================
-- QUERY 3: Alert Severity Distribution
-- ============================================
-- Business question: What is the current distribution of machine risk states?
-- Grain: One row per risk level

SELECT 
    risk_level,
    COUNT(*) as record_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE), 2) as pct_of_total
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================
-- QUERY 4: Sensor Maxima vs Risk Level Correlation
-- ============================================
-- Business question: Are high vibration/temperature levels driving critical alerts?
-- Grain: One row per risk level

SELECT 
    risk_level,
    ROUND(AVG(min_health_score), 2) as avg_min_health,
    ROUND(AVG(max_temperature_c), 2) as avg_max_temp_c,
    ROUND(AVG(max_vibration), 4) as avg_max_vibration,
    ROUND(AVG(max_power_kw), 2) as avg_max_power_kw,
    SUM(total_anomalies) as total_anomalies
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
GROUP BY 1
ORDER BY avg_min_health ASC;


-- ============================================
-- QUERY 5: Equipment Anomaly Rate Leaderboard
-- ============================================
-- Business question: Which equipment generates the highest percentage of anomalies?
-- Grain: One row per equipment

SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    SUM(total_anomalies) as total_anomalies_recorded,
    SUM(total_readings) as total_readings_taken,
    ROUND(SUM(total_anomalies) * 100.0 / NULLIF(SUM(total_readings), 0), 2) as overall_anomaly_rate_pct,
    MIN(min_health_score) as historic_lowest_health
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
GROUP BY 1, 2
ORDER BY overall_anomaly_rate_pct DESC;
