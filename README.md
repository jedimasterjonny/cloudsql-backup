# CloudSQL Backup
Backup CloudSQL databases to Google Cloud Storage buckets.

## Usage

- Either create or reuse an exisiting service account to run the function, which has the following permission: 
  - `cloudsql.instances.export`
- Deploy this function to a Cloud Function with the following parameters:
  - Memory Allocated: 128 MiB
  - Trigger: HTTP
  - Runtime: Node.js 10
  - Function to execute: exportDatabase
  - Timeout: 60 seconds
  - Ingress settings: Allow all traffic
  - Envionment variables:
    - PROJECT: your_project_id
    - INSTANCE: cloudsql_instance_storing_db
    - BUCKET: target_bucket_for_backup
    - DB: db_to_backup
- The export runs as the database instance default service account, *not* the service account of the function invoker - as such this requires the following permissions:
  - `roles/storage.objectCreator` - To create the backup object
  - `roles/storage.objectViewer` - To validate the backup object
- (Optional) Create a Cloud Scheduler entry with the following parameters:
  - Frequency: your_crontab
  - Target: HTTP
  - URL: url_of_cloud_function
  - HTTP method: GET
  - Auth header: Add OIDC token
  - Service account: account_that_can_invoke_cloud_functions
  - Audience: url_of_cloud_function
