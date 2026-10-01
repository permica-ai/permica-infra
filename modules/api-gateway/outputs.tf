output "gateway_url" {
  description = "The public URL host of the API Gateway"
  value       = "https://${google_api_gateway_gateway.gateway.default_hostname}"
}

output "gateway_service_account" {
  description = "Service account used by API Gateway to invoke backend"
  value       = google_service_account.gateway.email
}
