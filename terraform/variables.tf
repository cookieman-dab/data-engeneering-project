variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "bucket_name" {
  description = "GCS Bucket name (globale e unico)"
  type        = string
}

variable "service_account_id" {
  description = "Service Account ID"
  type        = string
  default     = "bruin-sa"
}
