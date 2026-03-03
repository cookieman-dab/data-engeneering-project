import requests
import os
import json
from google.cloud import storage
import io
import csv

client = storage.Client()
bucket_name = os.getenv("GCP_BUCKET", "solar-raw-dab-2026-unique")
bucket = client.bucket(bucket_name)

locations = json.loads(os.getenv("LOCATIONS", '[{"id":"Roma","lat":41.9,"lon":12.5}]'))
start_date = os.getenv("START_DATE", "2023-01-01").replace("-", "")
end_date = os.getenv("END_DATE", "2023-12-31").replace("-", "")

for loc in locations:
    url = (
        f"https://power.larc.nasa.gov/api/temporal/daily/point"
        f"?parameters=ALLSKY_SFC_SW_DWN,T2M,CLRSKY_SFC_SW_DWN"
        f"&community=RE"
        f"&longitude={loc['lon']}&latitude={loc['lat']}"
        f"&start={start_date}&end={end_date}"
        f"&format=CSV"
    )

    response = requests.get(url)
    
    # 1️⃣ Leggi CSV come testo
    csv_text = response.text
    
    # 2️⃣ Trova inizio dati (dopo END HEADER)
    data_start = csv_text.find("YEAR,MO,DY")  # Prima riga dati
    clean_csv = csv_text[data_start:]  # Taglia header
    
    # 3️⃣ Salva su GCS
    blob_name = f"raw/nasa_{loc['id']}_{start_date}_{end_date}_clean.csv"
    blob = bucket.blob(blob_name)
    blob.upload_from_string(clean_csv)
    
    print(f"✅ {loc['id']}: {len(clean_csv.splitlines())} righe pulite")

# Coefficiente termico standard dei pannelli silicio cristallino
#TEMP_COEFFICIENT = -0.004  # -0.4% per °C
#NOCT = 25                  # temperatura nominale di riferimento

# Correzione per temperatura
#temp_factor = 1 + TEMP_COEFFICIENT * (T2M - NOCT)

# Correzione per nuvolosità (quanta irradianza è persa rispetto al cielo sereno)
#cloud_factor = ALLSKY_SFC_SW_DWN / CLRSKY_SFC_SW_DWN  # es. 0.75 = 25% perso per nuvole

# Formula completa
#kWh = (ALLSKY_SFC_SW_DWN * panel_area * efficiency * temp_factor) / 1000