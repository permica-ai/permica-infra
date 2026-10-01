output "gateway_url" {
  description = "The public URL host of the API Gateway"
  value       = "https://${google_api_gateway_gateway.gateway.default_hostname}"
}

output "gateway_service_account" {
  description = "Service account used by API Gateway to invoke backend"
  value       = google_service_account.gateway.email
}

output "api_key" {
  description = "Generated GCP API Key for calling the API Gateway endpoints"
  value       = google_apikeys_key.api_key.key_string
  sensitive   = true
}

