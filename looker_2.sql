SELECT 
  location_id,
  year_month,
  ROUND(AVG(estimated_kwh), 2) AS media_kwh_giorno_mese
FROM `solar_mart.solar_production`
WHERE year_month IS NOT NULL
GROUP BY location_id, year_month
ORDER BY location_id, year_month
