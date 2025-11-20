#!/bin/bash
set -e

# MLflow Installation and Configuration Script
# This script sets up MLflow with MySQL backend and OCI Object Storage

echo "=========================================="
echo "MLflow Setup - Starting Installation"
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install Python 3.9 and dependencies
echo "Installing Python 3.9 and dependencies..."
sudo yum install -y python39 python39-pip python39-devel gcc gcc-c++ make git wget

# Install MySQL client
echo "Installing MySQL client..."
sudo yum install -y mysql

# Set Python 3.9 as default
sudo alternatives --set python3 /usr/bin/python3.9

# Upgrade pip
python3 -m pip install --upgrade pip

# Install MLflow and dependencies
echo "Installing MLflow and dependencies..."
pip3 install mlflow==2.10.0 \
    pymysql==1.1.0 \
    cryptography==41.0.7 \
    boto3==1.34.0 \
    oci==2.119.1

# Install OCI CLI
echo "Installing OCI CLI..."
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults

# Add OCI CLI to PATH
echo 'export PATH=$PATH:/root/bin' >> /home/opc/.bashrc
export PATH=$PATH:/root/bin

# Configure OCI for Object Storage access
echo "Configuring OCI authentication..."
mkdir -p /home/opc/.oci
cat > /home/opc/.oci/config <<EOF
[DEFAULT]
region=${region}
EOF
chown -R opc:opc /home/opc/.oci

# Wait for database to be ready
echo "Waiting for database to be ready..."
DB_HOST="${db_host}"
DB_PORT="${db_port}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
DB_NAME="${db_name}"

MAX_RETRIES=30
RETRY_COUNT=0
until mysql -h $DB_HOST -P $DB_PORT -u admin -p"$DB_PASSWORD" -e "SELECT 1" &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Database not ready after $MAX_RETRIES attempts"
        exit 1
    fi
    echo "Waiting for database... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done

echo "Database is ready!"

# Create MLflow database and user
echo "Setting up MLflow database..."
mysql -h $DB_HOST -P $DB_PORT -u admin -p"$DB_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Configure MLflow environment variables
echo "Configuring MLflow environment..."
cat > /home/opc/mlflow.env <<EOF
export MLFLOW_BACKEND_STORE_URI="mysql+pymysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
export MLFLOW_ARTIFACT_ROOT="oci://${bucket_name}@${bucket_namespace}/mlflow-artifacts"
export MLFLOW_TRACKING_URI="http://0.0.0.0:${mlflow_port}"
export OCI_REGION="${region}"
EOF

source /home/opc/mlflow.env
echo 'source /home/opc/mlflow.env' >> /home/opc/.bashrc

# Create systemd service for MLflow
echo "Creating MLflow systemd service..."
sudo cat > /etc/systemd/system/mlflow.service <<EOF
[Unit]
Description=MLflow Tracking Server
After=network.target

[Service]
Type=simple
User=opc
WorkingDirectory=/home/opc
EnvironmentFile=/home/opc/mlflow.env
ExecStart=/usr/local/bin/mlflow server \\
    --backend-store-uri mysql+pymysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME \\
    --default-artifact-root oci://${bucket_name}@${bucket_namespace}/mlflow-artifacts \\
    --host 0.0.0.0 \\
    --port ${mlflow_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start MLflow service
echo "Starting MLflow service..."
sudo systemctl daemon-reload
sudo systemctl enable mlflow.service
sudo systemctl start mlflow.service

# Wait for MLflow to be ready
echo "Waiting for MLflow to start..."
sleep 10

# Check MLflow status
if sudo systemctl is-active --quiet mlflow.service; then
    echo "=========================================="
    echo "MLflow installation completed successfully!"
    echo "MLflow Tracking URI: http://$(hostname -I | awk '{print $1}'):${mlflow_port}"
    echo "=========================================="
else
    echo "ERROR: MLflow service failed to start"
    sudo journalctl -u mlflow.service -n 50
    exit 1
fi

# Create health check script
cat > /home/opc/health_check.sh <<'EOF'
#!/bin/bash
response=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:${mlflow_port}/health)
if [ "$response" = "200" ]; then
    echo "MLflow is healthy"
    exit 0
else
    echo "MLflow is unhealthy"
    exit 1
fi
EOF

chmod +x /home/opc/health_check.sh

echo "MLflow setup completed!"
