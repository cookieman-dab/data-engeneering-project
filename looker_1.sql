SELECT 
  location_id,
  COUNT(*) AS total_giorni,
  ROUND(SUM(estimated_kwh), 1) AS total_kwh_prodotto
FROM `solar_mart.solar_production`
GROUP BY location_id
ORDER BY total_kwh_prodotto DESC
