# Comandos Úteis - Projeto MLOps OCI

## 🚀 Deploy e Terraform

### Deploy Inicial
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Ver Outputs
```bash
terraform output
terraform output -json | jq
terraform output mlflow_url
```

### Atualizar Infraestrutura
```bash
terraform plan
terraform apply
```

### Destruir Infraestrutura
```bash
terraform destroy
# Confirme com: yes
```

### Refresh Estado
```bash
terraform refresh
terraform state list
terraform state show oci_core_instance.mlflow_instance
```

## 🔧 OCI CLI

### Listar Instâncias
```bash
oci compute instance list --compartment-id <compartment_id> --output table
```

### Obter IP de Instância
```bash
oci compute instance list-vnics --instance-id <instance_id> | jq '.data[0]."public-ip"'
```

### Listar Buckets
```bash
oci os bucket list --compartment-id <compartment_id>
```

### Upload para Bucket
```bash
oci os object put --bucket-name <bucket-name> --file <local-file> --name <object-name>
```

### Download de Bucket
```bash
oci os object get --bucket-name <bucket-name> --name <object-name> --file <local-file>
```

### Listar Databases
```bash
oci mysql db-system list --compartment-id <compartment_id> --output table
```

## 🐳 Acesso SSH

### Conectar a Instâncias
```bash
# MLflow
ssh -i ~/.ssh/mlops_key opc@<mlflow_ip>

# Airflow
ssh -i ~/.ssh/mlops_key opc@<airflow_ip>

# API
ssh -i ~/.ssh/mlops_key opc@<api_ip>
```

### Tunnel SSH (acesso local)
```bash
# MLflow
ssh -i ~/.ssh/mlops_key -L 5000:localhost:5000 opc@<mlflow_ip>
# Acesse: http://localhost:5000

# Airflow
ssh -i ~/.ssh/mlops_key -L 8080:localhost:8080 opc@<airflow_ip>
# Acesse: http://localhost:8080
```

## 📊 Monitoramento de Serviços

### Status dos Serviços
```bash
# Em cada instância
sudo systemctl status mlflow
sudo systemctl status airflow-webserver
sudo systemctl status airflow-scheduler
sudo systemctl status fastapi
sudo systemctl status streamlit
```

### Restart de Serviços
```bash
sudo systemctl restart mlflow
sudo systemctl restart airflow-webserver
sudo systemctl restart airflow-scheduler
sudo systemctl restart fastapi
sudo systemctl restart streamlit
```

### Logs em Tempo Real
```bash
# MLflow
sudo journalctl -u mlflow -f

# Airflow
sudo journalctl -u airflow-webserver -f
sudo journalctl -u airflow-scheduler -f

# API
sudo journalctl -u fastapi -f
sudo journalctl -u streamlit -f
```

### Ver Últimas 100 Linhas de Log
```bash
sudo journalctl -u mlflow -n 100 --no-pager
sudo journalctl -u airflow-webserver -n 100 --no-pager
```

## 🗄️ Banco de Dados MySQL

### Conectar ao Banco
```bash
# De qualquer instância
mysql -h <db_endpoint> -u admin -p
# Digite a senha
```

### Queries Úteis
```sql
-- Listar databases
SHOW DATABASES;

-- Usar database do MLflow
USE mlflow;
SHOW TABLES;

-- Ver experimentos
SELECT * FROM experiments;

-- Ver runs
SELECT * FROM runs ORDER BY start_time DESC LIMIT 10;

-- Usar database do Airflow
USE airflow;

-- Ver DAGs
SELECT dag_id, is_active, last_parsed_time FROM dag;

-- Ver últimas execuções
SELECT dag_id, state, start_date FROM dag_run ORDER BY start_date DESC LIMIT 10;
```

## 🔍 Diagnóstico

### Recursos do Sistema
```bash
# CPU e memória
htop
# ou
top

# Uso de disco
df -h

# Uso por diretório
du -sh /home/opc/*

# Processos Python
ps aux | grep python
```

### Teste de Conectividade
```bash
# Testar porta
nc -zv <ip> <port>

# Testar HTTP
curl -v http://<ip>:<port>

# Health checks
curl http://<mlflow_ip>:5000/health
curl http://<airflow_ip>:8080/health
curl http://<api_ip>:8000/
```

### Rede
```bash
# Portas abertas
sudo netstat -tulpn
# ou
sudo ss -tulpn

# Firewall
sudo firewall-cmd --list-all

# DNS
nslookup <hostname>
```

## 📦 Gerenciamento de DAGs

### Upload de DAG
```bash
# Via OCI CLI
oci os object put \
  --bucket-name <bucket-name> \
  --file dags/my_dag.py \
  --name my_dag.py
```

### Sincronizar DAGs Manualmente
```bash
# Na instância Airflow
ssh opc@<airflow_ip>
/home/opc/sync_dags.sh
```

### Listar DAGs no Airflow
```bash
# Via Airflow CLI
ssh opc@<airflow_ip>
export AIRFLOW_HOME=/home/opc/airflow
airflow dags list
```

### Testar DAG
```bash
# Parse test
airflow dags list-import-errors

# Trigger manual
airflow dags trigger <dag_id>
```

## 🤖 MLflow

### Via Python
```python
import mlflow

# Configurar
mlflow.set_tracking_uri("http://<mlflow_ip>:5000")

# Listar experimentos
experiments = mlflow.search_experiments()
for exp in experiments:
    print(exp.name, exp.experiment_id)

# Listar runs
runs = mlflow.search_runs(experiment_ids=["0"])
print(runs[["run_id", "metrics.accuracy", "params.n_estimators"]])

# Registrar modelo
mlflow.register_model("runs:/<run_id>/model", "MyModel")
```

### Via CLI (na instância)
```bash
ssh opc@<mlflow_ip>

# Listar experimentos
mlflow experiments list

# Ver detalhes de run
mlflow runs describe --run-id <run_id>
```

## 🌐 Testes de API

### FastAPI
```bash
# Health check
curl http://<api_ip>:8000/

# Listar modelos
curl http://<api_ip>:8000/models

# Fazer predição
curl -X POST "http://<api_ip>:8000/predict/MyModel/1" \
  -H "Content-Type: application/json" \
  -d '{"data": [[5.1, 3.5, 1.4, 0.2]]}'
```

### Via Python
```python
import requests

# Listar modelos
response = requests.get("http://<api_ip>:8000/models")
print(response.json())

# Predição
data = {"data": [[5.1, 3.5, 1.4, 0.2]]}
response = requests.post(
    "http://<api_ip>:8000/predict/MyModel/Production",
    json=data
)
print(response.json())
```

## 🔐 Segurança

### Gerar Nova Chave SSH
```bash
ssh-keygen -t rsa -b 4096 -C "mlops-key" -f ~/.ssh/mlops_key_new
```

### Atualizar Chave SSH nas Instâncias
```bash
# Via Terraform
# Atualize terraform.tfvars com nova chave
ssh_public_key = "ssh-rsa AAAAB3..."

# Apply
terraform apply
```

### Mudar Senha do Banco
```bash
# Via MySQL
mysql -h <db_endpoint> -u admin -p
ALTER USER 'admin'@'%' IDENTIFIED BY 'NovaSenha123!';
FLUSH PRIVILEGES;
```

## 📝 Backup

### Backup Manual de Buckets
```bash
# Download completo
oci os object bulk-download \
  --bucket-name <bucket-name> \
  --download-dir ./backup_$(date +%Y%m%d)
```

### Backup do Banco de Dados
```bash
# Dump do banco MLflow
ssh opc@<mlflow_ip>
mysqldump -h <db_endpoint> -u admin -p mlflow > mlflow_backup_$(date +%Y%m%d).sql

# Dump do banco Airflow
mysqldump -h <db_endpoint> -u admin -p airflow > airflow_backup_$(date +%Y%m%d).sql
```

### Restore de Backup
```bash
mysql -h <db_endpoint> -u admin -p mlflow < mlflow_backup_20241119.sql
```

## 🧹 Manutenção

### Limpar Logs Antigos
```bash
# Limpar journalctl
sudo journalctl --vacuum-time=7d

# Limpar logs do Airflow
rm -rf /home/opc/airflow/logs/dag_id/*/$(date -d '30 days ago' +%Y-%m-%d)
```

### Atualizar Pacotes
```bash
# Sistema
sudo yum update -y

# Python packages
pip3 install --upgrade mlflow airflow fastapi streamlit
```

### Limpar Cache de Modelos (API)
```bash
curl -X DELETE http://<api_ip>:8000/cache
```

## 🔄 CI/CD

### Trigger Manual do Workflow
```bash
# Via GitHub CLI
gh workflow run deploy.yml -f action=apply

# Via API
curl -X POST \
  -H "Authorization: token <GITHUB_TOKEN>" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/<owner>/<repo>/actions/workflows/deploy.yml/dispatches \
  -d '{"ref":"main","inputs":{"action":"apply"}}'
```

### Ver Logs do Workflow
```bash
gh run list
gh run view <run-id>
gh run view <run-id> --log
```

## 📊 Métricas e Monitoramento

### Uso de CPU
```bash
# Tempo real
mpstat 1

# Histórico
sar -u 1 10
```

### Uso de Memória
```bash
free -h
vmstat 1 10
```

### I/O de Disco
```bash
iostat -x 1 10
```

### Tráfego de Rede
```bash
iftop
# ou
nethogs
```

---

**Dica**: Salve este arquivo localmente e adapte os comandos com seus IPs e nomes!
