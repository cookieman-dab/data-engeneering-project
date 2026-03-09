/* @bruin

name: solar_staging.stg_solar_irradiance
type: bq.sql
materialization:
  type: table

depends:
  - ingest.nasa_power_ingest

columns:
  - name: date
    type: date
    checks:
      - name: not_null
  - name: location_id
    type: string
    checks:
      - name: not_null
  - name: irradiance_kwh_m2
    type: float64
    description: "All-sky surface shortwave downward irradiance (kW-hr/m²/day)"
    checks:
      - name: not_null
      - name: positive
  - name: clrsky_irradiance_kwh_m2
    type: float64
    description: "Clear-sky surface shortwave downward irradiance (kW-hr/m²/day)"
    checks:
      - name: positive
  - name: temperature_c
    type: float64
    description: "Temperature at 2 meters (°C)"
    checks:
      - name: not_null

@bruin */

SELECT
  DATE(YEAR, MO, DY) AS date,
  location_id,
  ALLSKY_SFC_SW_DWN AS irradiance_kwh_m2,
  CLRSKY_SFC_SW_DWN AS clrsky_irradiance_kwh_m2,
  T2M AS temperature_c
FROM solar_raw.nasa_irradiance
WHERE ALLSKY_SFC_SW_DWN != -999
  AND T2M != -999
  AND CLRSKY_SFC_SW_DWN != -999