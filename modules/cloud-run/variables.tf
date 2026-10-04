variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "image" {
  description = "Initial image only. After the first deploy, CI controls the image."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "service_account_email" {
  type = string
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

variable "env_vars" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "ENV_VAR_NAME => Secret Manager secret ID (latest version is mounted)."
  type        = map(string)
  default     = {}
}

variable "enable_cloud_sql" {
  type    = bool
  default = false
}

variable "cloud_sql_connection_name" {
  type    = string
  default = ""
}

variable "cloud_sql_connection_names" {
  description = "List of Cloud SQL instance connection names to mount under /cloudsql."
  type        = list(string)
  default     = []
}


variable "allow_public_access" {
  description = "Allow unauthenticated invocations (the app must do its own auth)."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
