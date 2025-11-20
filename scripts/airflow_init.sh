#!/bin/bash
set -e

# Airflow Installation and Configuration Script
# This script sets up Apache Airflow with MySQL backend and OCI Object Storage

echo "=========================================="
echo "Airflow Setup - Starting Installation"
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install Python 3.9 and dependencies
echo "Installing Python 3.9 and dependencies..."
sudo yum install -y python39 python39-pip python39-devel gcc gcc-c++ make git wget \
    libffi-devel openssl-devel sqlite-devel bzip2-devel

# Install MySQL client
echo "Installing MySQL client..."
sudo yum install -y mysql

# Set Python 3.9 as default
sudo alternatives --set python3 /usr/bin/python3.9

# Upgrade pip
python3 -m pip install --upgrade pip

# Set Airflow home
export AIRFLOW_HOME=/home/opc/airflow
mkdir -p $AIRFLOW_HOME

# Install Airflow with MySQL and OCI providers
echo "Installing Apache Airflow..."
AIRFLOW_VERSION=2.8.0
PYTHON_VERSION="$(python3 --version | cut -d " " -f 2 | cut -d "." -f 1-2)"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-$${AIRFLOW_VERSION}/constraints-$${PYTHON_VERSION}.txt"

pip3 install "apache-airflow[mysql,celery,crypto,oci]==$${AIRFLOW_VERSION}" --constraint "$${CONSTRAINT_URL}"

# Install additional dependencies
pip3 install mlflow==2.10.0 \
    pymysql==1.1.0 \
    oci==2.119.1 \
    boto3==1.34.0

# Install OCI CLI
echo "Installing OCI CLI..."
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults

# Add OCI CLI to PATH
echo 'export PATH=$PATH:/root/bin' >> /home/opc/.bashrc
export PATH=$PATH:/root/bin

# Configure OCI
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

# Create Airflow database and user
echo "Setting up Airflow database..."
mysql -h $DB_HOST -P $DB_PORT -u admin -p"$DB_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Configure Airflow
echo "Configuring Airflow..."
cat > $AIRFLOW_HOME/airflow.cfg <<EOF
[core]
dags_folder = $AIRFLOW_HOME/dags
base_log_folder = $AIRFLOW_HOME/logs
executor = LocalExecutor
sql_alchemy_conn = mysql+pymysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME
load_examples = False
default_timezone = utc

[webserver]
base_url = http://0.0.0.0:${airflow_port}
web_server_host = 0.0.0.0
web_server_port = ${airflow_port}

[scheduler]
dag_dir_list_interval = 30

[logging]
remote_logging = False

[mlflow]
tracking_uri = ${mlflow_url}
EOF

# Create environment file
cat > /home/opc/airflow.env <<EOF
export AIRFLOW_HOME=$AIRFLOW_HOME
export AIRFLOW__CORE__SQL_ALCHEMY_CONN="mysql+pymysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
export AIRFLOW__CORE__EXECUTOR=LocalExecutor
export AIRFLOW__CORE__LOAD_EXAMPLES=False
export MLFLOW_TRACKING_URI="${mlflow_url}"
export OCI_REGION="${region}"
export DAGS_BUCKET="${bucket_name}"
export DAGS_NAMESPACE="${bucket_namespace}"
EOF

source /home/opc/airflow.env
echo 'source /home/opc/airflow.env' >> /home/opc/.bashrc

# Create DAGs directory
mkdir -p $AIRFLOW_HOME/dags
mkdir -p $AIRFLOW_HOME/logs
mkdir -p $AIRFLOW_HOME/plugins

# Initialize Airflow database
echo "Initializing Airflow database..."
airflow db init

# Create admin user
echo "Creating Airflow admin user..."
airflow users create \
    --username admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com \
    --password admin

# Create DAG sync script
cat > /home/opc/sync_dags.sh <<EOF
#!/bin/bash
# Sync DAGs from OCI Object Storage
oci os object bulk-download --bucket-name ${bucket_name} --namespace ${bucket_namespace} --download-dir $AIRFLOW_HOME/dags --overwrite
EOF

chmod +x /home/opc/sync_dags.sh

# Create systemd service for DAG sync (runs every 5 minutes)
sudo cat > /etc/systemd/system/airflow-dag-sync.service <<EOF
[Unit]
Description=Airflow DAG Sync from OCI Object Storage

[Service]
Type=oneshot
User=opc
ExecStart=/home/opc/sync_dags.sh
EOF

sudo cat > /etc/systemd/system/airflow-dag-sync.timer <<EOF
[Unit]
Description=Run Airflow DAG Sync every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Create systemd service for Airflow webserver
sudo cat > /etc/systemd/system/airflow-webserver.service <<EOF
[Unit]
Description=Airflow Webserver
After=network.target

[Service]
Type=simple
User=opc
EnvironmentFile=/home/opc/airflow.env
ExecStart=/usr/local/bin/airflow webserver --port ${airflow_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Airflow scheduler
sudo cat > /etc/systemd/system/airflow-scheduler.service <<EOF
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
Type=simple
User=opc
EnvironmentFile=/home/opc/airflow.env
ExecStart=/usr/local/bin/airflow scheduler
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo "Starting Airflow services..."
sudo systemctl daemon-reload
sudo systemctl enable airflow-webserver.service
sudo systemctl enable airflow-scheduler.service
sudo systemctl enable airflow-dag-sync.timer
sudo systemctl start airflow-webserver.service
sudo systemctl start airflow-scheduler.service
sudo systemctl start airflow-dag-sync.timer

# Wait for services to start
echo "Waiting for Airflow to start..."
sleep 15

# Check services status
if sudo systemctl is-active --quiet airflow-webserver.service && \
   sudo systemctl is-active --quiet airflow-scheduler.service; then
    echo "=========================================="
    echo "Airflow installation completed successfully!"
    echo "Airflow URL: http://$(hostname -I | awk '{print $1}'):${airflow_port}"
    echo "Username: admin"
    echo "Password: admin"
    echo "=========================================="
else
    echo "ERROR: Airflow services failed to start"
    sudo journalctl -u airflow-webserver.service -n 50
    sudo journalctl -u airflow-scheduler.service -n 50
    exit 1
fi

echo "Airflow setup completed!"
