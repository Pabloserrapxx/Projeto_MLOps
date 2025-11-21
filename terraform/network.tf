# Get the availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "mlops_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = var.vcn_cidr
  display_name   = "${var.project_name}-vcn-${var.environment}"
  dns_label      = "mlopsvcn"

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Internet Gateway
resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-igw-${var.environment}"
  enabled        = true

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# NAT Gateway (for private subnet)
resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-nat-${var.environment}"

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Service Gateway (for OCI services access)
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "service_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-sgw-${var.environment}"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Route Table for Public Subnet
resource "oci_core_route_table" "public_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-public-rt-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
    description       = "Route to Internet Gateway"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Route Table for Private Subnet
resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-private-rt-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
    description       = "Route to NAT Gateway"
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.service_gateway.id
    description       = "Route to Service Gateway"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Security List for Public Subnet
resource "oci_core_security_list" "public_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-public-sl-${var.environment}"

  # Egress Rules - Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound traffic"
  }

  # Ingress Rules - SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow SSH"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress Rules - MLflow
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow MLflow"
    tcp_options {
      min = var.mlflow_port
      max = var.mlflow_port
    }
  }

  # Ingress Rules - Airflow
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow Airflow"
    tcp_options {
      min = var.airflow_port
      max = var.airflow_port
    }
  }

  # Ingress Rules - FastAPI
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow FastAPI"
    tcp_options {
      min = var.fastapi_port
      max = var.fastapi_port
    }
  }

  # Ingress Rules - Streamlit
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow Streamlit"
    tcp_options {
      min = var.streamlit_port
      max = var.streamlit_port
    }
  }

  # Allow internal VCN traffic
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Allow all internal VCN traffic"
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Security List for Private Subnet
resource "oci_core_security_list" "private_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.mlops_vcn.id
  display_name   = "${var.project_name}-private-sl-${var.environment}"

  # Egress Rules - Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound traffic"
  }

  # Ingress Rules - Allow from VCN
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "Allow all from VCN"
  }

  # Ingress Rules - MySQL
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.vcn_cidr
    description = "Allow MySQL from VCN"
    tcp_options {
      min = 3306
      max = 3306
    }
  }

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Public Subnet
resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.mlops_vcn.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.project_name}-public-subnet-${var.environment}"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public_route_table.id
  security_list_ids          = [oci_core_security_list.public_security_list.id]

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}

# Private Subnet
resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.mlops_vcn.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${var.project_name}-private-subnet-${var.environment}"
  dns_label                  = "private"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_route_table.id
  security_list_ids          = [oci_core_security_list.private_security_list.id]

  freeform_tags = {
    "Project"     = var.project_name
    "Environment" = var.environment
  }
}
