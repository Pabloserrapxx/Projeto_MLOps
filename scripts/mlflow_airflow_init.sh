#!/bin/bash
# MLflow + Airflow consolidated initialization script

set -e

echo "Starting MLflow + Airflow installation..."

# Update system
sudo yum update -y
sudo yum install -y python3 python3-pip mysql git

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker opc

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install MySQL Server locally
sudo yum install -y mysql-server
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Wait for MySQL to start
sleep 10

# Create databases
sudo mysql -e "CREATE DATABASE IF NOT EXISTS mlflow;"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS airflow;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'mlflow'@'localhost' IDENTIFIED BY '${db_admin_password}';"
sudo mysql -e "CREATE USER IF NOT EXISTS 'airflow'@'localhost' IDENTIFIED BY '${db_admin_password}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON mlflow.* TO 'mlflow'@'localhost';"
sudo mysql -e "GRANT ALL PRIVILEGES ON airflow.* TO 'airflow'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Install Python packages
sudo pip3 install mlflow==2.10.0 apache-airflow==2.8.0 pymysql

# Configure MLflow
sudo mkdir -p /opt/mlflow
sudo chown opc:opc /opt/mlflow

# Create MLflow systemd service
cat <<EOF | sudo tee /etc/systemd/system/mlflow.service
[Unit]
Description=MLflow Server
After=network.target

[Service]
User=opc
WorkingDirectory=/opt/mlflow
ExecStart=/usr/local/bin/mlflow server \\
    --backend-store-uri mysql+pymysql://mlflow:${db_admin_password}@localhost:3306/mlflow \\
    --default-artifact-root oci://${mlflow_bucket}@${bucket_namespace}/ \\
    --host 0.0.0.0 \\
    --port ${mlflow_port}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Configure Airflow
export AIRFLOW_HOME=/opt/airflow
sudo mkdir -p $AIRFLOW_HOME
sudo chown opc:opc $AIRFLOW_HOME

# Initialize Airflow DB
sudo -u opc AIRFLOW_HOME=$AIRFLOW_HOME airflow db init

# Create Airflow admin user
sudo -u opc AIRFLOW_HOME=$AIRFLOW_HOME airflow users create \\
    --username admin \\
    --firstname Admin \\
    --lastname User \\
    --role Admin \\
    --email admin@example.com \\
    --password admin123

# Create Airflow systemd services
cat <<EOF | sudo tee /etc/systemd/system/airflow-webserver.service
[Unit]
Description=Airflow Webserver
After=network.target

[Service]
User=opc
Environment=AIRFLOW_HOME=/opt/airflow
ExecStart=/usr/local/bin/airflow webserver --port ${airflow_port}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/airflow-scheduler.service
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
User=opc
Environment=AIRFLOW_HOME=/opt/airflow
ExecStart=/usr/local/bin/airflow scheduler
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable mlflow airflow-webserver airflow-scheduler
sudo systemctl start mlflow airflow-webserver airflow-scheduler

# Configure firewall
sudo firewall-cmd --permanent --add-port=${mlflow_port}/tcp
sudo firewall-cmd --permanent --add-port=${airflow_port}/tcp
sudo firewall-cmd --reload

echo "MLflow + Airflow installation completed!"
echo "MLflow: http://$(hostname -I | awk '{print $1}'):${mlflow_port}"
echo "Airflow: http://$(hostname -I | awk '{print $1}'):${airflow_port}"
