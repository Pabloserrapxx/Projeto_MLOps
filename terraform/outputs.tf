# Network Outputs
output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.mlops_vcn.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private_subnet.id
}

# Compute Outputs
output "mlflow_instance_public_ip" {
  description = "Public IP of MLflow instance"
  value       = oci_core_instance.mlflow_instance.public_ip
}

output "mlflow_instance_private_ip" {
  description = "Private IP of MLflow instance"
  value       = oci_core_instance.mlflow_instance.private_ip
}

output "airflow_instance_public_ip" {
  description = "Public IP of Airflow instance"
  value       = oci_core_instance.airflow_instance.public_ip
}

output "airflow_instance_private_ip" {
  description = "Private IP of Airflow instance"
  value       = oci_core_instance.airflow_instance.private_ip
}

output "api_instance_public_ip" {
  description = "Public IP of API/Streamlit instance"
  value       = oci_core_instance.api_instance.public_ip
}

output "api_instance_private_ip" {
  description = "Private IP of API/Streamlit instance"
  value       = oci_core_instance.api_instance.private_ip
}

# Database Outputs
output "mysql_endpoint" {
  description = "MySQL Database endpoint"
  value       = oci_core_instance.airflow_instance.private_ip
}

output "mysql_port" {
  description = "MySQL Database port"
  value       = 3306
}

# Storage Outputs
output "mlflow_bucket_name" {
  description = "Name of MLflow artifacts bucket"
  value       = oci_objectstorage_bucket.mlflow_bucket.name
}

output "mlflow_bucket_namespace" {
  description = "Namespace of MLflow artifacts bucket"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "airflow_bucket_name" {
  description = "Name of Airflow DAGs bucket"
  value       = oci_objectstorage_bucket.airflow_bucket.name
}

output "airflow_bucket_namespace" {
  description = "Namespace of Airflow DAGs bucket"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

# Access URLs
output "mlflow_url" {
  description = "MLflow tracking server URL"
  value       = "http://${oci_core_instance.mlflow_instance.public_ip}:${var.mlflow_port}"
}

output "airflow_url" {
  description = "Airflow webserver URL"
  value       = "http://${oci_core_instance.airflow_instance.public_ip}:${var.airflow_port}"
}

output "fastapi_url" {
  description = "FastAPI server URL"
  value       = "http://${oci_core_instance.api_instance.public_ip}:${var.fastapi_port}"
}

output "streamlit_url" {
  description = "Streamlit app URL"
  value       = "http://${oci_core_instance.api_instance.public_ip}:${var.streamlit_port}"
}

# Connection Information
output "connection_info" {
  description = "Connection information for all services"
  value = {
    mlflow = {
      public_ip  = oci_core_instance.mlflow_instance.public_ip
      private_ip = oci_core_instance.mlflow_instance.private_ip
      url        = "http://${oci_core_instance.mlflow_instance.public_ip}:${var.mlflow_port}"
    }
    airflow = {
      public_ip  = oci_core_instance.airflow_instance.public_ip
      private_ip = oci_core_instance.airflow_instance.private_ip
      url        = "http://${oci_core_instance.airflow_instance.public_ip}:${var.airflow_port}"
    }
    api = {
      public_ip    = oci_core_instance.api_instance.public_ip
      private_ip   = oci_core_instance.api_instance.private_ip
      fastapi_url  = "http://${oci_core_instance.api_instance.public_ip}:${var.fastapi_port}"
      streamlit_url = "http://${oci_core_instance.api_instance.public_ip}:${var.streamlit_port}"
    }
    database = {
      endpoint = oci_core_instance.airflow_instance.private_ip
      port     = 3306
    }
  }
}
