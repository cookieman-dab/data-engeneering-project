/* @bruin

name: solar_mart.solar_production
type: bq.sql
materialization:
  type: table

depends:
  - solar_staging.stg_solar_irradiance

columns:
  - name: date
    type: date
    checks:
      - name: not_null
  - name: location_id
    type: string
    checks:
      - name: not_null
  - name: estimated_kwh
    type: float64
    description: "Estimated daily kWh production per panel"
    checks:
      - name: not_null

@bruin */

-- Panel parameters (global, from .env defaults)
-- PANEL_AREA = 1.7 m²
-- PANEL_EFFICIENCY = 0.20 (20%)
-- TEMP_COEFFICIENT = -0.004 (-0.4% per °C)
-- NOCT = 25°C (nominal operating cell temperature)

SELECT
  date,
  location_id,

  -- Raw NASA values
  irradiance_kwh_m2,
  clrsky_irradiance_kwh_m2,
  temperature_c,

  -- Correction factors
  -- Temperature derating: panels lose ~0.4% efficiency per °C above 25°C
  ROUND(1 + (-0.004) * (temperature_c - 25), 4) AS temp_factor,

  -- Cloud factor: ratio of actual vs clear-sky irradiance
  ROUND(
    SAFE_DIVIDE(irradiance_kwh_m2, clrsky_irradiance_kwh_m2),
    4
  ) AS cloud_factor,

  -- ═══ Estimated kWh per day ═══
  -- Formula: irradiance (kWh/m²/day) × panel_area (m²) × efficiency × temp_correction
  -- NASA ALLSKY_SFC_SW_DWN is already in kW-hr/m²/day
  ROUND(
    irradiance_kwh_m2
    * 1.7                                          -- panel_area m²
    * 0.20                                         -- panel_efficiency
    * (1 + (-0.004) * (temperature_c - 25)),       -- temp_factor
    4
  ) AS estimated_kwh,

  -- Monthly aggregate helper
  FORMAT_DATE('%Y-%m', date) AS year_month

FROM solar_staging.stg_solar_irradiance
