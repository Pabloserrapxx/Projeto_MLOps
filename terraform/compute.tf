# Get latest Oracle Linux image
data "oci_core_images" "oracle_linux_images" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.mlflow_instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# MLflow Instance
resource "oci_core_instance" "mlflow_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.project_name}-mlflow-${var.environment}"
  shape               = var.mlflow_instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "mlflow-vnic"
    assign_public_ip = true
    hostname_label   = "mlflow"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/../scripts/mlflow_init.sh", {
      db_host              = oci_mysql_mysql_db_system.mlops_db.endpoints[0].hostname
      db_port              = oci_mysql_mysql_db_system.mlops_db.endpoints[0].port
      db_user              = "mlflow"
      db_password          = var.db_admin_password
      db_name              = "mlflow"
      bucket_name          = oci_objectstorage_bucket.mlflow_bucket.name
      bucket_namespace     = data.oci_objectstorage_namespace.ns.namespace
      mlflow_port          = var.mlflow_port
      region               = var.region
    }))
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "MLflow"
  }

  depends_on = [
    oci_mysql_mysql_db_system.mlops_db,
    oci_objectstorage_bucket.mlflow_bucket
  ]
}

# Airflow Instance
resource "oci_core_instance" "airflow_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.project_name}-airflow-${var.environment}"
  shape               = var.airflow_instance_shape

  shape_config {
    ocpus         = var.airflow_ocpus
    memory_in_gbs = var.airflow_memory_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "airflow-vnic"
    assign_public_ip = true
    hostname_label   = "airflow"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/../scripts/airflow_init.sh", {
      db_host          = oci_mysql_mysql_db_system.mlops_db.endpoints[0].hostname
      db_port          = oci_mysql_mysql_db_system.mlops_db.endpoints[0].port
      db_user          = "airflow"
      db_password      = var.db_admin_password
      db_name          = "airflow"
      bucket_name      = oci_objectstorage_bucket.airflow_bucket.name
      bucket_namespace = data.oci_objectstorage_namespace.ns.namespace
      airflow_port     = var.airflow_port
      region           = var.region
      mlflow_url       = "http://${oci_core_instance.mlflow_instance.private_ip}:${var.mlflow_port}"
    }))
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "Airflow"
  }

  depends_on = [
    oci_mysql_mysql_db_system.mlops_db,
    oci_objectstorage_bucket.airflow_bucket,
    oci_core_instance.mlflow_instance
  ]
}

# API/Streamlit Instance
resource "oci_core_instance" "api_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.project_name}-api-${var.environment}"
  shape               = var.api_instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "api-vnic"
    assign_public_ip = true
    hostname_label   = "api"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/../scripts/api_init.sh", {
      mlflow_url      = "http://${oci_core_instance.mlflow_instance.private_ip}:${var.mlflow_port}"
      fastapi_port    = var.fastapi_port
      streamlit_port  = var.streamlit_port
      region          = var.region
    }))
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "API"
  }

  depends_on = [
    oci_core_instance.mlflow_instance
  ]
}
