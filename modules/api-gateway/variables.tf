variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "api_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cloud_run_url" {
  description = "Target backend Cloud Run service URL"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Backend Cloud Run service name"
  type        = string
}

variable "labels" {
  type    = map(string)
  default = {}
}
