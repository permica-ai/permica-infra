# Creates secret "containers" (values for these are added out-of-band, never in Git),
# plus one secret whose value Terraform generates: the database password.

resource "google_secret_manager_secret" "managed" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "managed_accessor" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = google_secret_manager_secret.managed[each.value].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = var.accessor_member
}

# ---- database password (value lives in Secret Manager and in the protected state bucket)
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "db-password"
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  count       = var.create_db_password_version ? 1 : 0
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}


resource "google_secret_manager_secret_iam_member" "db_password_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = var.accessor_member
}
