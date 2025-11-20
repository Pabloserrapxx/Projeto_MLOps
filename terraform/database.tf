# MySQL Database System for MLflow and Airflow metadata
resource "oci_mysql_mysql_db_system" "mlops_db" {
  compartment_id      = var.compartment_id
  shape_name          = var.db_shape
  subnet_id           = oci_core_subnet.private_subnet.id
  admin_password      = var.db_admin_password
  admin_username      = "admin"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  display_name        = "${var.project_name}-mysql-${var.environment}"
  hostname_label      = "mlopsdb"

  data_storage_size_in_gb = 50
  
  backup_policy {
    is_enabled        = true
    retention_in_days = 7
    window_start_time = "03:00"
  }

  maintenance {
    window_start_time = "sun 03:00"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# MySQL Configuration for MLflow database
resource "oci_mysql_mysql_configuration" "mlops_config" {
  compartment_id = var.compartment_id
  shape_name     = var.db_shape
  display_name   = "${var.project_name}-mysql-config-${var.environment}"

  variables {
    max_connections = "500"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}
