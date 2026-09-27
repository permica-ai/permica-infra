variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "app_name" {
  type = string
}

variable "github_repo" {
  description = "owner/name of the GitHub repo that deploys the app."
  type        = string
}

variable "developer_members" {
  description = "IAM members with developer access, e.g. [\"group:myapp-devs@example.com\"]"
  type        = list(string)
  default     = []
}

variable "admin_members" {
  description = "IAM members with admin access, e.g. [\"group:myapp-admins@example.com\"]"
  type        = list(string)
  default     = []
}

variable "enable_cloud_sql" {
  description = "Enable PostgreSQL (Cloud SQL) database."
  type        = bool
  default     = true
}

variable "enable_cloud_run" {
  description = "Enable Cloud Run service."
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Enable Cloud Storage bucket."
  type        = bool
  default     = true
}

variable "enable_artifact_registry" {
  description = "Enable Artifact Registry repository."
  type        = bool
  default     = true
}

variable "enable_scheduler" {
  description = "Enable Cloud Scheduler jobs."
  type        = bool
  default     = true
}

variable "enable_secrets" {
  description = "Enable Secret Manager secrets."
  type        = bool
  default     = true
}

variable "enable_bigtable" {
  description = "Bigtable has a high minimum cost (~1 node always on). Turn off if you do not need it here."
  type        = bool
  default     = true
}

variable "bigtable_tables" {
  type = map(object({
    column_families = list(string)
  }))
  default = {}
}

variable "scheduler_jobs" {
  type = map(object({
    schedule    = string
    path        = string
    http_method = optional(string, "POST")
    time_zone   = optional(string, "Etc/UTC")
  }))
  default = {}
}

variable "extra_secret_env" {
  description = "ENV_VAR => secret ID, once the secret has a value."
  type        = map(string)
  default     = {}
}

variable "allow_public_access" {
  description = "Allow unauthenticated HTTP calls to Cloud Run (set false if forbidden by org policy)."
  type        = bool
  default     = false
}

