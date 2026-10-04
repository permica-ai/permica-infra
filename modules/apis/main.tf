resource "google_project_service" "this" {
  for_each = toset(var.services)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "time_sleep" "wait_api_enablement" {
  depends_on = [google_project_service.this]

  create_duration = "30s"
}

