# Get Object Storage namespace
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

# Random ID for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# MLflow Artifacts Bucket
resource "oci_objectstorage_bucket" "mlflow_bucket" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.project_name}-${var.mlflow_bucket_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  access_type    = "NoPublicAccess"

  versioning = "Enabled"

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "MLflow"
  }
}

# Airflow DAGs Bucket
resource "oci_objectstorage_bucket" "airflow_bucket" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.project_name}-${var.airflow_bucket_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  access_type    = "NoPublicAccess"

  versioning = "Enabled"

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "Airflow"
  }
}

# PAR (Pre-Authenticated Request) for MLflow bucket (optional, for temporary access)
resource "oci_objectstorage_preauthrequest" "mlflow_par" {
  namespace    = data.oci_objectstorage_namespace.ns.namespace
  bucket       = oci_objectstorage_bucket.mlflow_bucket.name
  name         = "mlflow-access-${var.environment}"
  access_type  = "AnyObjectWrite"
  time_expires = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [time_expires]
  }
}

# PAR for Airflow bucket (optional, for temporary access)
resource "oci_objectstorage_preauthrequest" "airflow_par" {
  namespace    = data.oci_objectstorage_namespace.ns.namespace
  bucket       = oci_objectstorage_bucket.airflow_bucket.name
  name         = "airflow-access-${var.environment}"
  access_type  = "AnyObjectWrite"
  time_expires = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [time_expires]
  }
}
