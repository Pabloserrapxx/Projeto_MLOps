# Get latest Oracle Linux image
data "oci_core_images" "oracle_linux_images" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Instance 1: MLflow + Airflow (consolidated)
resource "oci_core_instance" "mlops_backend" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.project_name}-backend-${var.environment}"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "mlops-backend-vnic"
    assign_public_ip = true
    hostname_label   = "mlopsbackend"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(var.ssh_public_key)
    user_data = base64encode(templatefile("${path.module}/../scripts/mlflow_airflow_init.sh", {
      db_host           = "localhost"
      db_port           = "3306"
      db_admin_password = var.db_admin_password
      mlflow_bucket     = oci_objectstorage_bucket.mlflow_bucket.name
      airflow_bucket    = oci_objectstorage_bucket.airflow_bucket.name
      bucket_namespace  = data.oci_objectstorage_namespace.ns.namespace
      mlflow_port       = var.mlflow_port
      airflow_port      = var.airflow_port
      region            = var.region
    }))
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "MLflow-Airflow"
  }

  depends_on = [
    oci_objectstorage_bucket.mlflow_bucket,
    oci_objectstorage_bucket.airflow_bucket
  ]
}

# Instance 2: API + Streamlit (consolidated)
resource "oci_core_instance" "mlops_frontend" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.project_name}-frontend-${var.environment}"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "mlops-frontend-vnic"
    assign_public_ip = true
    hostname_label   = "mlopsfrontend"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(var.ssh_public_key)
    user_data = base64encode(templatefile("${path.module}/../scripts/api_streamlit_init.sh", {
      mlflow_url     = "http://mlopsbackend.public.mlopsvcn.oraclevcn.com:${var.mlflow_port}"
      fastapi_port   = var.fastapi_port
      streamlit_port = var.streamlit_port
      region         = var.region
    }))
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
    "Service"     = "API-Streamlit"
  }
}
