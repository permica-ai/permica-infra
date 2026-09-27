terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "this" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier                        = var.tier
    edition                     = "ENTERPRISE"
    availability_type           = var.availability_type
    disk_type                   = "PD_SSD"
    disk_size                   = var.disk_size
    disk_autoresize             = true
    deletion_protection_enabled = var.deletion_protection
    user_labels                 = var.labels

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
    }

    # PostGIS extension is available out of the box in Cloud SQL PostgreSQL.
    # Flags can be configured here if required.
    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_sql_database" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database_name
}

resource "google_sql_user" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.user_name
  password = random_password.db.result
}
