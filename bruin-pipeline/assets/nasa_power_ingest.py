"""@bruin
name: ingest.nasa_power_ingest
type: python

depends: []

@bruin"""

import requests
import os
import json
import csv
import io
from google.cloud import storage, bigquery
from dotenv import load_dotenv, find_dotenv


def main():
    # ── Config from .env ──────────────────────────────────────
    # Locate .env by jumping two directories up relative to this file
    env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))
    load_dotenv(env_path)
    bucket_name = os.getenv("GCP_BUCKET", "solar-raw-dab-2026-unique")
    project_id = os.getenv("GCP_PROJECT_ID", "")
    locations = json.loads(
        os.getenv("LOCATIONS", '[{"id":"Roma","lat":41.9,"lon":12.5}]')
    )
    start_date = os.getenv("START_DATE", "2023-01-01").replace("-", "")
    end_date = os.getenv("END_DATE", "2023-01-31").replace("-", "")
    panel_area = float(os.getenv("PANEL_AREA", "1.7"))
    panel_efficiency = float(os.getenv("PANEL_EFFICIENCY", "0.20"))

    # ── GCP clients ───────────────────────────────────────────
    gcs_client = storage.Client(project=project_id)
    bucket = gcs_client.bucket(bucket_name)
    bq_client = bigquery.Client(project=project_id, location="US")

    # ── Ensure BigQuery table exists ──────────────────────────
    dataset_ref = bq_client.dataset("solar_raw")
    table_ref = dataset_ref.table("nasa_irradiance")

    schema = [
        bigquery.SchemaField("YEAR", "INTEGER"),
        bigquery.SchemaField("MO", "INTEGER"),
        bigquery.SchemaField("DY", "INTEGER"),
        bigquery.SchemaField("ALLSKY_SFC_SW_DWN", "FLOAT64"),
        bigquery.SchemaField("T2M", "FLOAT64"),
        bigquery.SchemaField("CLRSKY_SFC_SW_DWN", "FLOAT64"),
        bigquery.SchemaField("location_id", "STRING"),
    ]

    # Create or update table
    try:
        table = bq_client.get_table(table_ref)
        print(f"📋 Table {table_ref} already exists")
    except Exception:
        table = bigquery.Table(table_ref, schema=schema)
        table = bq_client.create_table(table)
        print(f"✅ Created table {table_ref}")

    # ── Process each location ─────────────────────────────────
    for loc in locations:
        loc_id = loc["id"]
        lat = loc["lat"]
        lon = loc["lon"]

        print(f"\n📡 Fetching data for {loc_id} (lat={lat}, lon={lon})...")

        # 1️⃣ Call NASA POWER API
        url = (
            f"https://power.larc.nasa.gov/api/temporal/daily/point"
            f"?parameters=ALLSKY_SFC_SW_DWN,T2M,CLRSKY_SFC_SW_DWN"
            f"&community=RE"
            f"&longitude={lon}&latitude={lat}"
            f"&start={start_date}&end={end_date}"
            f"&format=CSV"
        )

        response = requests.get(url, timeout=120)
        response.raise_for_status()
        csv_text = response.text

        # 2️⃣ Strip NASA header (everything before "YEAR,MO,DY")
        header_pos = csv_text.find("YEAR,MO,DY")
        if header_pos == -1:
            print(f"⚠️ {loc_id}: no data header found, skipping")
            continue
        clean_csv = csv_text[header_pos:]

        # 3️⃣ Upload raw CSV to GCS
        blob_name = f"raw/nasa_{loc_id}_{start_date}_{end_date}.csv"
        blob = bucket.blob(blob_name)
        blob.upload_from_string(clean_csv, content_type="text/csv")
        print(f"☁️  Uploaded to gs://{bucket_name}/{blob_name}")

        # 4️⃣ Parse CSV and load into BigQuery
        reader = csv.DictReader(io.StringIO(clean_csv))
        rows = []
        for row in reader:
            # Skip NASA missing data marker (-999)
            allsky = float(row["ALLSKY_SFC_SW_DWN"])
            t2m = float(row["T2M"])
            clrsky = float(row["CLRSKY_SFC_SW_DWN"])

            if allsky == -999 or t2m == -999 or clrsky == -999:
                continue

            rows.append({
                "YEAR": int(row["YEAR"]),
                "MO": int(row["MO"]),
                "DY": int(row["DY"]),
                "ALLSKY_SFC_SW_DWN": allsky,
                "T2M": t2m,
                "CLRSKY_SFC_SW_DWN": clrsky,
                "location_id": loc_id,
            })

        if rows:
            job_config = bigquery.LoadJobConfig(
                schema=schema,
                write_disposition="WRITE_APPEND",
            )
            job = bq_client.load_table_from_json(rows, table_ref, job_config=job_config)
            job.result()  # Wait for completion
            print(f"✅ {loc_id}: loaded {len(rows)} rows into BigQuery solar_raw.nasa_irradiance")
        else:
            print(f"⚠️  {loc_id}: no valid rows to load")

    print("\n🏁 Ingestion complete!")


if __name__ == "__main__":
    main()