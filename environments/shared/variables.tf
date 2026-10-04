variable "project_id" {
  description = "GCP Project ID for shared infrastructure."
  type        = string
}

variable "region" {
  description = "GCP Region for shared Cloud SQL instance."
  type        = string
  default     = "us-east1"
}

variable "app_name" {
  description = "Application name prefix."
  type        = string
  default     = "permica-ai"
}

variable "database_name" {
  description = "Shared PostgreSQL database name."
  type        = string
  default     = "permica-gis"
}

variable "sql_tier" {
  description = "Machine tier for shared Cloud SQL instance."
  type        = string
  default     = "db-custom-1-3840"
}

variable "sql_disk_size" {
  description = "Disk size in GB."
  type        = number
  default     = 30
}

variable "sql_availability_type" {
  description = "ZONAL or REGIONAL (high availability)."
  type        = string
  default     = "ZONAL"
}


variable "deletion_protection" {
  description = "Prevent accidental destruction of Cloud SQL instance."
  type        = bool
  default     = true
}

variable "dev_service_account_email" {
  description = "Service account email of dev Cloud Run runtime (granted roles/cloudsql.client)."
  type        = string
  default     = ""
}

variable "prod_service_account_email" {
  description = "Service account email of prod Cloud Run runtime (granted roles/cloudsql.client)."
  type        = string
  default     = ""
}

variable "developer_members" {
  type    = list(string)
  default = []
}

variable "admin_members" {
  type    = list(string)
  default = []
}
