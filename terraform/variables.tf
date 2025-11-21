# Oracle Cloud Infrastructure Variables
variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI Private Key"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "private_key_content" {
  description = "Content of the OCI Private Key (alternative to file path)"
  type        = string
  default     = null
  sensitive   = true
}

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

# Network Variables
variable "vcn_cidr" {
  description = "CIDR block for VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Compute Variables
variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "mlflow_instance_shape" {
  description = "Shape for MLflow instance"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "airflow_instance_shape" {
  description = "Shape for Airflow instance"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "api_instance_shape" {
  description = "Shape for API/Streamlit instance"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for flex instances"
  type        = number
  default     = 1
}

variable "instance_memory_gb" {
  description = "Memory in GB for flex instances"
  type        = number
  default     = 6
}

variable "airflow_ocpus" {
  description = "Number of OCPUs for Airflow instance"
  type        = number
  default     = 1
}

variable "airflow_memory_gb" {
  description = "Memory in GB for Airflow instance"
  type        = number
  default     = 6
}

# Database Variables
variable "db_admin_password" {
  description = "Admin password for MySQL Database"
  type        = string
  sensitive   = true
}

variable "db_shape" {
  description = "Shape for MySQL Database"
  type        = string
  default     = "MySQL.VM.Standard.E4.1.8GB"
}

# Storage Variables
variable "mlflow_bucket_name" {
  description = "Name for MLflow artifacts bucket"
  type        = string
  default     = "mlflow-artifacts"
}

variable "airflow_bucket_name" {
  description = "Name for Airflow DAGs bucket"
  type        = string
  default     = "airflow-dags"
}

# Project Variables
variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "mlops-project"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# MLflow Variables
variable "mlflow_port" {
  description = "Port for MLflow server"
  type        = number
  default     = 5000
}

# Airflow Variables
variable "airflow_port" {
  description = "Port for Airflow webserver"
  type        = number
  default     = 8080
}

# API Variables
variable "fastapi_port" {
  description = "Port for FastAPI server"
  type        = number
  default     = 8000
}

variable "streamlit_port" {
  description = "Port for Streamlit app"
  type        = number
  default     = 8501
}
