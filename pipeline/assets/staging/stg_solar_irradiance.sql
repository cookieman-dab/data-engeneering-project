-- staging.stg_solar_irradiance.sql
{{ config(
    materialized = 'table',
    partition_by = {'field': 'date', 'data_type': 'date'},
    cluster_by = ['location_id']
) }}

WITH parsed_csv AS (
  SELECT
    PARSE_DATE('%Y,%m,%d', CONCAT(YEAR, ',', MO, ',', DY)) AS date,
    location_id,
    SAFE_CAST(REPLACE(ALLSKY_SFC_SW_DWN, '.', '') AS FLOAT64) / 10000 AS irradiance_wh_m2,  -- NASA format: 0.8592 = 859.2 Wh/m²
    SAFE_CAST(T2M AS FLOAT64) AS temperature_c
  FROM `{{ var('project_id') }}.solar_raw.raw_nasa_*`,
  UNNEST([STRUCT('Roma' AS location_id)]) AS loc  -- estrai location_id dal nome file
  WHERE irradiance_wh_m2 IS NOT NULL
)

SELECT * FROM parsed_csv
