# Resolução de Problemas - MLOps OCI

Este guia ajuda a diagnosticar e resolver problemas comuns na infraestrutura MLOps.

## 📋 Índice

1. [Problemas de Deploy](#problemas-de-deploy)
2. [Problemas de Rede](#problemas-de-rede)
3. [Problemas de Serviços](#problemas-de-serviços)
4. [Problemas de Banco de Dados](#problemas-de-banco-de-dados)
5. [Problemas de Storage](#problemas-de-storage)
6. [Problemas de Performance](#problemas-de-performance)

## 🚨 Problemas de Deploy

### Erro: "Service timeout when creating database"

**Sintomas**: Deploy falha ao criar MySQL Database System.

**Causas**:
- Região escolhida sem disponibilidade
- Shape indisponível
- Limites de serviço atingidos

**Solução**:
```bash
# Verificar limites de serviço
oci limits value list --compartment-id <compartment_id> --service-name mysql

# Tentar região alternativa
# Edite terraform.tfvars:
region = "us-phoenix-1"  # ou outra região
```

### Erro: "Out of capacity for shape VM.Standard.E4.Flex"

**Sintomas**: Falha ao criar instâncias compute.

**Solução**:
```hcl
# Em terraform.tfvars, use shape Always Free:
mlflow_instance_shape = "VM.Standard.E2.1.Micro"
airflow_instance_shape = "VM.Standard.E2.1.Micro"
api_instance_shape = "VM.Standard.E2.1.Micro"

# Ou tente shape diferente:
mlflow_instance_shape = "VM.Standard.A1.Flex"  # ARM-based
```

### Erro: GitHub Actions - "Authentication failed"

**Sintomas**: Workflow falha com erro de autenticação.

**Solução**:
1. Verifique secrets no GitHub:
   - `OCI_TENANCY_OCID`
   - `OCI_USER_OCID`
   - `OCI_FINGERPRINT`
   - `OCI_PRIVATE_KEY`

2. Teste localmente:
```bash
# Configure OCI CLI
oci iam region list

# Se falhar, reconfigure
oci setup config
```

3. Verifique chave privada:
```bash
# Deve conter as linhas BEGIN/END
cat ~/.oci/oci_api_key.pem
```

### Erro: "Subnet has no available IP addresses"

**Sintomas**: Falha ao criar instâncias.

**Solução**:
```hcl
# Aumente CIDR da subnet em variables.tf
variable "public_subnet_cidr" {
  default = "10.0.1.0/23"  # De /24 para /23 (dobra IPs)
}
```

## 🌐 Problemas de Rede

### Não consigo acessar MLflow/Airflow/API

**Sintomas**: Timeout ao acessar IPs públicos.

**Diagnóstico**:
```bash
# Teste conectividade
ping <instance_ip>
curl -v http://<instance_ip>:5000

# Verifique se instância está rodando
ssh -i ~/.ssh/mlops_key opc@<instance_ip>
```

**Soluções**:

1. **Verificar Security List**:
   - Console OCI > Networking > Virtual Cloud Networks
   - Clique na VCN > Security Lists
   - Verifique se portas estão abertas: 22, 5000, 8080, 8000, 8501

2. **Verificar Firewall na Instância**:
```bash
ssh opc@<instance_ip>

# Verificar firewall
sudo firewall-cmd --list-all

# Se necessário, abrir portas
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --permanent --add-port=8501/tcp
sudo firewall-cmd --reload
```

3. **Verificar SELinux**:
```bash
sudo getenforce  # Se "Enforcing"
sudo setenforce 0  # Desabilitar temporariamente
```

### Instâncias não conseguem acessar MySQL

**Sintomas**: Logs mostram erro de conexão ao banco.

**Diagnóstico**:
```bash
ssh opc@<mlflow_ip>

# Testar conexão
mysql -h <db_endpoint> -u admin -p
# Digite a senha do DB_ADMIN_PASSWORD
```

**Soluções**:

1. **Verificar Private Subnet Security List**:
   - Deve permitir porta 3306 de 10.0.0.0/16

2. **Verificar MySQL está rodando**:
   - Console OCI > Databases > MySQL > DB Systems
   - Status deve ser "ACTIVE"

3. **Verificar endpoint**:
```bash
# Obter endpoint correto
terraform output mysql_endpoint
```

## 🔧 Problemas de Serviços

### MLflow não inicia

**Sintomas**: Porta 5000 não responde.

**Diagnóstico**:
```bash
ssh opc@<mlflow_ip>

# Verificar status
sudo systemctl status mlflow

# Ver logs
sudo journalctl -u mlflow -n 100 --no-pager
```

**Soluções Comuns**:

1. **Erro de conexão ao MySQL**:
```bash
# Verificar variáveis de ambiente
cat /home/opc/mlflow.env

# Testar conexão manualmente
mysql -h <db_host> -P <db_port> -u mlflow -p
```

2. **Reinstalar MLflow**:
```bash
sudo systemctl stop mlflow
pip3 install --upgrade mlflow==2.10.0
sudo systemctl start mlflow
```

3. **Verificar Object Storage**:
```bash
# Testar acesso ao bucket
oci os object list --bucket-name <mlflow-bucket>
```

### Airflow não inicia (Webserver ou Scheduler)

**Diagnóstico**:
```bash
ssh opc@<airflow_ip>

# Status dos serviços
sudo systemctl status airflow-webserver
sudo systemctl status airflow-scheduler

# Logs
sudo journalctl -u airflow-webserver -n 100
sudo journalctl -u airflow-scheduler -n 100
```

**Soluções**:

1. **Erro de memória (common com shapes menores)**:
```bash
# Aumentar swap
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

2. **Banco não inicializado**:
```bash
export AIRFLOW_HOME=/home/opc/airflow
airflow db init
airflow users create --username admin --password admin --role Admin --email admin@example.com --firstname Admin --lastname User
```

3. **Reiniciar serviços**:
```bash
sudo systemctl restart airflow-webserver
sudo systemctl restart airflow-scheduler
```

### FastAPI/Streamlit não respondem

**Diagnóstico**:
```bash
ssh opc@<api_ip>

# Status
sudo systemctl status fastapi
sudo systemctl status streamlit

# Logs
sudo journalctl -u fastapi -n 50
sudo journalctl -u streamlit -n 50
```

**Soluções**:

1. **Reinstalar dependências**:
```bash
pip3 install --upgrade fastapi uvicorn streamlit mlflow
sudo systemctl restart fastapi
sudo systemctl restart streamlit
```

2. **Verificar códigos de aplicação**:
```bash
cd /home/opc/app
ls -la  # Devem existir main.py e streamlit_app.py
```

3. **Testar manualmente**:
```bash
# FastAPI
cd /home/opc/app
source /home/opc/app.env
uvicorn main:app --host 0.0.0.0 --port 8000

# Streamlit (em outro terminal)
streamlit run streamlit_app.py --server.port 8501
```

## 💾 Problemas de Banco de Dados

### Erro: "Too many connections"

**Sintomas**: Serviços falham ao conectar ao MySQL.

**Solução**:
```bash
# Via SSH em qualquer instância
mysql -h <db_endpoint> -u admin -p

# No MySQL
SHOW VARIABLES LIKE 'max_connections';
SET GLOBAL max_connections = 500;

# Ou via Terraform (permanente)
# Em database.tf, ajuste:
variables {
  max_connections = "500"
}
```

### Banco de dados muito lento

**Diagnóstico**:
```bash
# Verificar queries lentas
mysql -h <db_endpoint> -u admin -p
SHOW PROCESSLIST;
```

**Soluções**:

1. **Aumentar shape do MySQL**:
```hcl
# Em terraform.tfvars
db_shape = "MySQL.VM.Standard.E4.2.16GB"  # Upgrade
```

2. **Criar índices**:
```sql
-- MLflow
USE mlflow;
SHOW INDEX FROM experiments;
CREATE INDEX idx_experiment_name ON experiments(name);

-- Airflow
USE airflow;
CREATE INDEX idx_dag_id ON dag_run(dag_id);
```

## 📦 Problemas de Storage

### DAGs não aparecem no Airflow

**Sintomas**: DAG enviada ao bucket não aparece na UI.

**Diagnóstico**:
```bash
ssh opc@<airflow_ip>

# Verificar sync
sudo systemctl status airflow-dag-sync.timer
sudo journalctl -u airflow-dag-sync.service -n 20

# Executar sync manualmente
/home/opc/sync_dags.sh

# Verificar DAGs locais
ls -la $AIRFLOW_HOME/dags/
```

**Soluções**:

1. **Reativar timer**:
```bash
sudo systemctl restart airflow-dag-sync.timer
```

2. **Upload manual de DAG**:
```bash
# Do seu computador
oci os object put \
  --bucket-name <airflow-bucket> \
  --file dags/my_dag.py \
  --name my_dag.py

# Na instância Airflow
/home/opc/sync_dags.sh
```

3. **Verificar permissões**:
```bash
ls -la $AIRFLOW_HOME/dags/
# Se necessário
chmod 755 $AIRFLOW_HOME/dags/*.py
```

### Erro ao salvar artefatos MLflow no Object Storage

**Sintomas**: `mlflow.log_artifact()` falha.

**Diagnóstico**:
```bash
ssh opc@<mlflow_ip>

# Testar acesso ao bucket
oci os object list --bucket-name <mlflow-bucket>
```

**Soluções**:

1. **Verificar configuração OCI**:
```bash
cat ~/.oci/config
# Deve ter:
# [DEFAULT]
# region=us-ashburn-1
```

2. **Testar upload manualmente**:
```bash
echo "test" > test.txt
oci os object put --bucket-name <mlflow-bucket> --file test.txt --name test.txt
```

3. **Verificar no código MLflow**:
```python
# Deve usar formato correto
artifact_uri = "oci://<bucket>@<namespace>/mlflow-artifacts"
```

## ⚡ Problemas de Performance

### Instâncias muito lentas

**Soluções**:

1. **Aumentar OCPUs/RAM**:
```hcl
# terraform.tfvars
instance_ocpus = 4
instance_memory_gb = 32
```

2. **Usar shapes ARM (mais baratos)**:
```hcl
mlflow_instance_shape = "VM.Standard.A1.Flex"
```

3. **Monitorar recursos**:
```bash
ssh opc@<instance_ip>

# CPU e memória
htop

# Disco
df -h
iostat -x 1
```

### Airflow Scheduler lento

**Soluções**:

1. **Ajustar configuração**:
```bash
ssh opc@<airflow_ip>

# Editar airflow.cfg
vi $AIRFLOW_HOME/airflow.cfg

# Ajustar:
[scheduler]
max_threads = 4
processor_poll_interval = 1
```

2. **Usar CeleryExecutor** (para DAGs pesadas):
   - Requer setup adicional com Redis/RabbitMQ

## 🔍 Comandos Úteis de Diagnóstico

### Verificar recursos do sistema

```bash
# CPU e memória
top
htop

# Disco
df -h
du -sh /home/opc/*

# Rede
netstat -tulpn
ss -tulpn

# Processos
ps aux | grep mlflow
ps aux | grep airflow
```

### Verificar conectividade

```bash
# Testar porta
nc -zv <ip> <port>

# Testar HTTP
curl -v http://<ip>:<port>

# DNS
nslookup <hostname>
dig <hostname>
```

### Logs importantes

```bash
# Systemd services
sudo journalctl -u mlflow -f
sudo journalctl -u airflow-webserver -f
sudo journalctl -u airflow-scheduler -f
sudo journalctl -u fastapi -f
sudo journalctl -u streamlit -f

# System logs
sudo tail -f /var/log/messages
sudo tail -f /var/log/cloud-init-output.log
```

## 🆘 Quando pedir ajuda

Se nenhuma solução funcionou:

1. **Colete informações**:
   - Versão do Terraform
   - Região OCI
   - Shapes usados
   - Logs completos dos serviços
   - Mensagens de erro exatas

2. **Crie issue no GitHub** com:
   - Descrição do problema
   - Passos para reproduzir
   - Logs relevantes
   - Configurações (sem senhas!)

3. **Consulte documentação oficial**:
   - [OCI Docs](https://docs.oracle.com/en-us/iaas/)
   - [MLflow Docs](https://mlflow.org/docs/latest/)
   - [Airflow Docs](https://airflow.apache.org/docs/)

## 🔄 Reset Completo

Se tudo falhou, reset completo:

```bash
# Destruir infraestrutura
cd terraform
terraform destroy

# Limpar estado
rm -rf .terraform
rm terraform.tfstate*

# Recriar
terraform init
terraform apply
```

---

**Última atualização**: Novembro 2025  
**Mantido por**: Pablo Serra
