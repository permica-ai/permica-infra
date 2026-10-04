output "enabled_services" {
  value      = [for s in google_project_service.this : s.service]
  depends_on = [time_sleep.wait_api_enablement]
}

