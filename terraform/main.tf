terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Provider SENZA credentials (usa GOOGLE_APPLICATION_CREDENTIALS dal Docker)
provider "google" {
  project = var.project_id
  region  = var.region
}

# GCS Bucket per raw JSON
resource "google_storage_bucket" "solar_raw" {
  name     = var.bucket_name
  location = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# BigQuery Datasets (3 layer)
resource "google_bigquery_dataset" "solar_raw" {
  dataset_id = "solar_raw"
  location   = var.region
}

resource "google_bigquery_dataset" "solar_staging" {
  dataset_id = "solar_staging"
  location   = var.region
}

resource "google_bigquery_dataset" "solar_mart" {
  dataset_id = "solar_mart"
  location   = var.region
}

# Service Account per Bruin pipeline
resource "google_service_account" "bruin_sa" {
  account_id   = var.service_account_id
  display_name = "Bruin Solar Pipeline SA"
}

# IAM Roles
resource "google_project_iam_member" "bruin_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.bruin_sa.email}"
}

resource "google_project_iam_member" "bruin_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.bruin_sa.email}"
}

# Crea automaticamente la chiave JSON
resource "google_service_account_key" "bruin_sa_key" {
  service_account_id = google_service_account.bruin_sa.name
  # La chiave viene scritta su disco locale
}

# Local file per copiarla in secrets/
resource "local_file" "bruin_sa_json" {
  content  = base64decode(google_service_account_key.bruin_sa_key.private_key)
  filename = "/secrets/bruin-sa.json"
}

# Outputs migliorati
output "service_account_email" {
  value = google_service_account.bruin_sa.email
}

output "bucket_name" {
  value = google_storage_bucket.solar_raw.name
}

output "bruin_sa_key_created" {
  value = "Chiave salvata in ../secrets/bruin-sa.json"
}
