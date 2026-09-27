# ---- identity of this environment
variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  description = "dev or prod"
  type        = string
}

variable "app_name" {
  type = string
}

variable "github_repo" {
  description = "owner/name of the GitHub repo allowed to deploy the app to this environment."
  type        = string
}

variable "deploy_branch" {
  description = "Branch allowed to deploy the app to this environment."
  type        = string
}

variable "deletion_protection" {
  description = "Protect Cloud SQL, Cloud Run and Bigtable from accidental deletion. true for prod."
  type        = bool
  default     = true
}

# ---- Cloud Run
variable "container_image" {
  description = "Placeholder image for the first deploy. CI replaces it afterwards."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 5
}

variable "allow_public_access" {
  type    = bool
  default = true
}

variable "extra_secret_env" {
  description = "Extra ENV_VAR => secret ID mappings. Add ONLY after the secret has a value (see README)."
  type        = map(string)
  default     = {}
}

# ---- Cloud SQL
variable "sql_tier" {
  type = string
}

variable "sql_availability_type" {
  type    = string
  default = "ZONAL"
}

variable "sql_disk_size" {
  type    = number
  default = 20
}

# ---- Component Toggles (SRE feature flags)
variable "enable_cloud_sql" {
  description = "Enable PostgreSQL (Cloud SQL) instance."
  type        = bool
  default     = true
}

variable "enable_cloud_run" {
  description = "Enable Cloud Run service deployment."
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Enable Cloud Storage bucket."
  type        = bool
  default     = true
}

variable "enable_artifact_registry" {
  description = "Enable Artifact Registry repository for container images."
  type        = bool
  default     = true
}

variable "enable_scheduler" {
  description = "Enable Cloud Scheduler cron jobs."
  type        = bool
  default     = true
}

variable "enable_secrets" {
  description = "Enable Secret Manager secrets provisioning."
  type        = bool
  default     = true
}

# ---- Bigtable
variable "enable_bigtable" {
  type    = bool
  default = true
}

variable "bigtable_num_nodes" {
  type    = number
  default = 1
}

variable "bigtable_storage_type" {
  type    = string
  default = "SSD"
}

variable "bigtable_tables" {
  type = map(object({
    column_families = list(string)
  }))
  default = {}
}

# ---- Secrets / Scheduler
variable "app_secrets" {
  description = "Secrets to create empty (you add the values). e.g. [\"jwt-secret\"]"
  type        = list(string)
  default     = ["jwt-secret"]
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

# ---- People
variable "developer_members" {
  type    = list(string)
  default = []
}

variable "developer_roles" {
  type    = list(string)
  default = []
}

variable "admin_members" {
  type    = list(string)
  default = []
}

variable "admin_roles" {
  type    = list(string)
  default = []
}
