# Service Account for API Gateway to invoke backend Cloud Run
resource "google_service_account" "gateway" {
  project      = var.project_id
  account_id   = "${var.api_name}-${var.environment}-gw"
  display_name = "API Gateway Service Account (${var.environment})"
}

# Grant Invoker permission to API Gateway SA on backend Cloud Run
resource "google_cloud_run_v2_service_iam_member" "gateway_invoker" {
  project  = var.project_id
  location = var.region
  name     = var.cloud_run_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.gateway.email}"
}

# API Gateway API Container
resource "google_api_gateway_api" "api" {
  provider     = google-beta
  project      = var.project_id
  api_id       = "${var.api_name}-${var.environment}-api"
  display_name = "${var.api_name} API (${var.environment})"
  labels       = var.labels
}

# API Gateway Config (OpenAPI Spec)
resource "google_api_gateway_api_config" "api_cfg" {
  provider             = google-beta
  project              = var.project_id
  api                  = google_api_gateway_api.api.api_id
  api_config_id_prefix = "cfg-"
  display_name         = "${var.api_name} Config (${var.environment})"
  labels               = var.labels

  openapi_documents {
    document {
      path = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/openapi.yaml.tftpl", {
        api_name      = var.api_name
        environment   = var.environment
        cloud_run_url = var.cloud_run_url
        gateway_host  = "${var.api_name}-${var.environment}-gw.gateway.dev"
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.gateway.email
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Instance
resource "google_api_gateway_gateway" "gateway" {
  provider     = google-beta
  project      = var.project_id
  region       = var.region
  gateway_id   = "${var.api_name}-${var.environment}-gw"
  api_config   = google_api_gateway_api_config.api_cfg.id
  display_name = "${var.api_name} Gateway (${var.environment})"
  labels       = var.labels
}

# Provision API Key for API Gateway
resource "google_apikeys_key" "api_key" {
  name         = "${var.api_name}-${var.environment}-key"
  display_name = "${var.api_name} Gateway API Key (${var.environment})"
  project      = var.project_id

  restrictions {
    api_targets {
      service = google_api_gateway_api.api.managed_service
    }
  }
}

