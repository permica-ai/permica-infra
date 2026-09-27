variable "app_name" {
  description = "Short app name, lowercase letters/digits/hyphens. Used in resource names (e.g. myapp)."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID, e.g. 0123AB-4567CD-89EF01. Find it with: gcloud billing accounts list"
  type        = string
}

variable "org_id" {
  description = "Numeric organization ID to create projects under. Leave null if you have no organization."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "Folder ID to create projects under (alternative to org_id). Leave null for none."
  type        = string
  default     = null
}

variable "dev_project_id" {
  description = "Globally unique project ID for dev, e.g. myapp-dev-123456. Leave null to auto-generate."
  type        = string
  default     = null
}

variable "prod_project_id" {
  description = "Globally unique project ID for prod, e.g. myapp-prod-123456. Leave null to auto-generate."
  type        = string
  default     = null
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "state_bucket_location" {
  description = "Location of the Terraform state buckets (multi-region US, or a region)."
  type        = string
  default     = "US"
}

variable "github_repo" {
  description = "GitHub repository that holds this infra code, as owner/name (e.g. myorg/myapp-infra)."
  type        = string
}

variable "dev_branch" {
  description = "Branch whose pushes are allowed to apply to dev."
  type        = string
  default     = "develop"
}

variable "prod_branch" {
  description = "Branch whose pushes are allowed to apply to prod."
  type        = string
  default     = "main"
}
