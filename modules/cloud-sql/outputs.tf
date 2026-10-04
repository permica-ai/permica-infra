output "connection_name" {
  value = google_sql_database_instance.this.connection_name
}

output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "database_name" {
  value = google_sql_database.app.name
}

output "user_name" {
  value = google_sql_user.app.name
}

output "password" {
  value     = random_password.db.result
  sensitive = true
}

output "user_passwords" {
  value = merge(
    { (var.user_name) = random_password.db.result },
    { for u in var.additional_users : u => random_password.additional_users[u].result }
  )
  sensitive = true
}

