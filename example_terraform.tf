# Cloud Scheduler service account
resource "google_service_account" "cloud_scheduler" {
  account_id   = "cloud-scheduler"
  display_name = "Cloud Scheduler service account"
}

# Cloud Scheduler can invoke Cloud Functions
resource "google_project_iam_binding" "cloud_scheduler" {
  role = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.cloud_scheduler.email}"
  ]
}

# Custom CloudSQL exporter role
resource "google_project_iam_custom_role" "cloudsql_exporter" {
  role_id     = "cloudsqlExporter"
  title       = "Cloud SQL Exporter"
  description = "Provides export permissions to CloudSQL resources"
  permissions = ["cloudsql.instances.export"]
}

# App Engine is a CloudSQL exporter to allow CloudSQL backup function to run
resource "google_project_iam_binding" "cloudsql_exporter" {
  role = google_project_iam_custom_role.cloudsql_exporter.id

  members = [
    "serviceAccount:${google_service_account.app_engine.email}"
  ]
}

# CloudSQL backup bucket
# Lifecycle
## 30 days - Nearline
## 90 days - Coldline
## 1 yr - Archive
## 5 yrs - delete
resource "google_storage_bucket" "cloudsql_backup" {
  name     = "${google_project.website.project_id}-cloudsql-backup"
  location = "US"

  bucket_policy_only = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      storage_class = "NEARLINE"
      type          = "SetStorageClass"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      storage_class = "COLDLINE"
      type          = "SetStorageClass"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      storage_class = "ARCHIVE"
      type          = "SetStorageClass"
    }
  }

  lifecycle_rule {
    condition {
      age = 1825
    }
    action {
      type = "Delete"
    }
  }
}

# CloudSQL service account can write to buckets
resource "google_storage_bucket_iam_binding" "cloudsql_backup_write" {
  bucket = google_storage_bucket.cloudsql_backup.name
  role   = "roles/storage.objectCreator"

  members = [
    "serviceAccount:${google_sql_database_instance.my_db.service_account_email_address}"
  ]
}

# CloudSQL service account can read from buckets to validate the backup
resource "google_storage_bucket_iam_binding" "cloudsql_backup_read" {
  bucket = google_storage_bucket.cloudsql_backup.name
  role   = "roles/storage.objectViewer"

  members = [
    "serviceAccount:${google_sql_database_instance.my_db.service_account_email_address}"
  ]
}

# Function to export a CloudSQL database to a GCS bucket
resource "google_cloudfunctions_function" "cloudsql_backup" {
  name        = "cloudsql-backup"
  description = "CloudSQL export to Cloud Storage"
  runtime     = "nodejs10"

  available_memory_mb = "128"
  timeout             = 60
  entry_point         = "exportDatabase"
  trigger_http        = true
  ingress_settings    = "ALLOW_ALL" # The ingress is still IAM controlled

  environment_variables = {
    "BUCKET"   = google_storage_bucket.cloudsql_backup.name
    "DB"       = google_sql_database.my_db.name
    "INSTANCE" = google_sql_database_instance.my_db.name
    "PROJECT"  = google_project.website.project_id
  }
}

# Backup CloudSQL to a GCS bucket daily at 4AM
resource "google_cloud_scheduler_job" "cloudsql_backup" {
  name             = "cloudsql-backup"
  description      = "Daily CloudSQL Backup"
  schedule         = "0 4 * * *"
  time_zone        = "Europe/London"
  attempt_deadline = "180s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions_function.cloudsql_backup.https_trigger_url

    oidc_token {
      audience              = google_cloudfunctions_function.cloudsql_backup.https_trigger_url
      service_account_email = google_service_account.cloud_scheduler.email
    }
  }
}
