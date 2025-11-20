# Arquitetura Detalhada - MLOps na Oracle Cloud

## 📐 Visão Geral

Esta documentação detalha a arquitetura completa da solução MLOps implementada na Oracle Cloud Infrastructure (OCI), explicando cada componente, suas interações e decisões de design.

## 🏗️ Componentes da Infraestrutura

### 1. Camada de Rede (VCN - Virtual Cloud Network)

#### Virtual Cloud Network
- **CIDR**: 10.0.0.0/16 (65,536 endereços IP)
- **Função**: Rede isolada para toda a infraestrutura
- **DNS Label**: mlopsvcn

#### Subnet Pública (10.0.1.0/24)
- **Capacidade**: 256 IPs
- **Recursos hospedados**:
  - MLflow Tracking Server
  - Airflow Web Server
  - FastAPI + Streamlit Server
- **Conectividade**: Acesso direto à internet via Internet Gateway
- **Uso**: Serviços que precisam ser acessados externamente

#### Subnet Privada (10.0.2.0/24)
- **Capacidade**: 256 IPs
- **Recursos hospedados**:
  - MySQL Database System
- **Conectividade**: Acesso à internet via NAT Gateway (apenas saída)
- **Uso**: Serviços que não devem ser expostos publicamente

#### Gateways

**Internet Gateway**
- Permite comunicação bidirecional entre subnet pública e internet
- Usado por instâncias públicas para receber requisições

**NAT Gateway**
- Permite instâncias privadas acessarem internet (apenas saída)
- Usado pelo MySQL para updates e patches

**Service Gateway**
- Conexão privada com serviços OCI (Object Storage, etc.)
- Tráfego não passa pela internet pública
- Reduz custos e aumenta segurança

#### Route Tables

**Public Route Table**
- 0.0.0.0/0 → Internet Gateway (todo tráfego público)

**Private Route Table**
- 0.0.0.0/0 → NAT Gateway (saída para internet)
- OCI Services CIDR → Service Gateway (serviços OCI)

#### Security Lists

**Public Security List** (Ingress):
- SSH (22): 0.0.0.0/0
- MLflow (5000): 0.0.0.0/0
- Airflow (8080): 0.0.0.0/0
- FastAPI (8000): 0.0.0.0/0
- Streamlit (8501): 0.0.0.0/0
- Internal VCN: 10.0.0.0/16

**Private Security List** (Ingress):
- MySQL (3306): 10.0.0.0/16
- All from VCN: 10.0.0.0/16

**Ambos** (Egress):
- All traffic: 0.0.0.0/0

### 2. Camada de Computação

#### MLflow Instance

**Configuração**:
- **Shape**: VM.Standard.E4.Flex
  - 2 OCPUs
  - 16GB RAM
- **OS**: Oracle Linux 8
- **Storage**: Boot volume de 50GB

**Serviços Instalados**:
- Python 3.9
- MLflow 2.10.0
- PyMySQL (para conexão ao MySQL)
- OCI SDK (para Object Storage)
- MySQL Client

**Arquitetura Interna**:
```
┌─────────────────────────────────────┐
│      MLflow Tracking Server         │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   MLflow REST API (Port 5000) │ │
│  └───────────────┬───────────────┘ │
│                  │                  │
│  ┌───────────────▼───────────────┐ │
│  │   Backend Store (MySQL)       │ │
│  │   - Experiments               │ │
│  │   - Runs                      │ │
│  │   - Metrics/Params            │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │  Artifact Store (OCI Storage) │ │
│  │   - Models                    │ │
│  │   - Artifacts                 │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Systemd Service**:
- Nome: `mlflow.service`
- Tipo: Simple
- Restart: Always
- User: opc

**Conexões**:
- MySQL (private_ip:3306) para metadados
- Object Storage via Service Gateway para artefatos
- Recebe requisições na porta 5000

#### Airflow Instance

**Configuração**:
- **Shape**: VM.Standard.E4.Flex
  - 2 OCPUs
  - 16GB RAM (maior que MLflow devido overhead do Airflow)
- **OS**: Oracle Linux 8
- **Storage**: Boot volume de 50GB

**Serviços Instalados**:
- Python 3.9
- Apache Airflow 2.8.0
- MLflow Client (para integração)
- OCI SDK
- MySQL Client

**Arquitetura Interna**:
```
┌─────────────────────────────────────┐
│       Apache Airflow                │
│                                     │
│  ┌───────────────────────────────┐ │
│  │  Webserver (Port 8080)        │ │
│  │  - UI                         │ │
│  │  - REST API                   │ │
│  └───────────────┬───────────────┘ │
│                  │                  │
│  ┌───────────────▼───────────────┐ │
│  │     Scheduler                 │ │
│  │  - DAG parsing               │ │
│  │  - Task scheduling           │ │
│  └───────────────┬───────────────┘ │
│                  │                  │
│  ┌───────────────▼───────────────┐ │
│  │   Local Executor              │ │
│  │  - Task execution             │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   Metadata DB (MySQL)         │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │  DAGs Sync (Timer)            │ │
│  │  - Pull from Object Storage   │ │
│  │  - Every 5 minutes            │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Systemd Services**:
1. `airflow-webserver.service`: UI e REST API
2. `airflow-scheduler.service`: Agendamento de tarefas
3. `airflow-dag-sync.timer`: Sincronização de DAGs (5 min)

**Conexões**:
- MySQL (private_ip:3306) para metadados
- Object Storage para buscar DAGs
- MLflow (mlflow_private_ip:5000) para logging

#### API Instance (FastAPI + Streamlit)

**Configuração**:
- **Shape**: VM.Standard.E4.Flex
  - 2 OCPUs
  - 16GB RAM
- **OS**: Oracle Linux 8
- **Storage**: Boot volume de 50GB

**Serviços Instalados**:
- Python 3.9
- FastAPI 0.109.0
- Streamlit 1.31.0
- MLflow Client
- Scikit-learn (para carregar modelos)

**Arquitetura Interna**:
```
┌─────────────────────────────────────┐
│    API/Visualization Server         │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   FastAPI (Port 8000)         │ │
│  │  ┌─────────────────────────┐  │ │
│  │  │ REST Endpoints:         │  │ │
│  │  │ - GET /models           │  │ │
│  │  │ - POST /predict         │  │ │
│  │  │ - GET /health           │  │ │
│  │  └─────────────────────────┘  │ │
│  │  ┌─────────────────────────┐  │ │
│  │  │ Model Cache             │  │ │
│  │  │ - In-memory models      │  │ │
│  │  └─────────────────────────┘  │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   Streamlit (Port 8501)       │ │
│  │  ┌─────────────────────────┐  │ │
│  │  │ Pages:                  │  │ │
│  │  │ - Models Overview       │  │ │
│  │  │ - Model Prediction      │  │ │
│  │  │ - Experiments           │  │ │
│  │  └─────────────────────────┘  │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │   MLflow Client               │ │
│  │  - Load models                │ │
│  │  - Query experiments          │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Systemd Services**:
1. `fastapi.service`: API REST
2. `streamlit.service`: Dashboard web

**Conexões**:
- MLflow (mlflow_private_ip:5000) para buscar modelos
- Não acessa banco diretamente

### 3. Camada de Dados

#### MySQL Database System

**Configuração**:
- **Shape**: MySQL.VM.Standard.E4.1.8GB
  - 1 OCPU
  - 8GB RAM
- **Storage**: 50GB
- **Versão**: MySQL 8.0
- **Backup**: Automático (7 dias de retenção)

**Databases**:

**Database: mlflow**
- **User**: mlflow
- **Tables principais**:
  - `experiments`: Armazena experimentos
  - `runs`: Registra runs de treinamento
  - `metrics`: Métricas dos modelos
  - `params`: Hiperparâmetros
  - `tags`: Tags dos runs
  - `registered_models`: Modelos registrados
  - `model_versions`: Versões dos modelos

**Database: airflow**
- **User**: airflow
- **Tables principais**:
  - `dag`: Definições de DAGs
  - `dag_run`: Execuções de DAGs
  - `task_instance`: Instâncias de tasks
  - `xcom`: Cross-communication entre tasks
  - `variable`: Variáveis do Airflow
  - `connection`: Conexões configuradas

**Alta Disponibilidade**:
- Backup automático diário às 03:00 UTC
- Janela de manutenção: Domingos às 03:00 UTC
- Retenção de backups: 7 dias

**Segurança**:
- Localizado em subnet privada
- Acesso apenas de IPs internos da VCN
- Senha forte (mínimo 8 caracteres)

#### Object Storage

**MLflow Artifacts Bucket**

**Configuração**:
- **Nome**: `{project_name}-mlflow-artifacts-{environment}`
- **Versionamento**: Habilitado
- **Acesso**: NoPublicAccess (apenas via API)

**Estrutura de Diretórios**:
```
mlflow-artifacts/
├── 0/                          # Experiment ID
│   ├── {run_id}/
│   │   ├── artifacts/
│   │   │   ├── model/
│   │   │   │   ├── MLmodel
│   │   │   │   ├── model.pkl
│   │   │   │   ├── conda.yaml
│   │   │   │   └── requirements.txt
│   │   │   ├── plots/
│   │   │   └── data/
```

**Uso de Storage**:
- Modelos treinados (~1-100MB por modelo)
- Plots e gráficos
- Datasets de exemplo
- Logs de treinamento

**Airflow DAGs Bucket**

**Configuração**:
- **Nome**: `{project_name}-airflow-dags-{environment}`
- **Versionamento**: Habilitado
- **Acesso**: NoPublicAccess

**Estrutura de Diretórios**:
```
airflow-dags/
├── example_iris_pipeline.py
├── production_training.py
├── data_validation.py
└── model_deployment.py
```

**Sincronização**:
- Timer executa a cada 5 minutos
- Script bash baixa todos os arquivos .py
- Copia para `$AIRFLOW_HOME/dags/`

### 4. Camada de Automação

#### CI/CD Pipeline (GitHub Actions)

**Workflow: deploy.yml**

**Triggers**:
- Push para `main` ou `develop`
- Pull Request para `main`
- Manual dispatch

**Jobs**:

**1. terraform-validation**
```yaml
- Checkout código
- Setup Terraform
- terraform fmt -check
- terraform init
- terraform validate
- Comentar resultado no PR
```

**2. terraform-plan**
```yaml
- Checkout código
- Configurar credenciais OCI
- terraform init
- terraform plan
- Salvar plano como artifact
- Comentar plano no PR
```

**3. terraform-apply**
```yaml
- Checkout código
- Configurar credenciais OCI
- terraform init
- terraform apply -auto-approve
- Coletar outputs
- Gerar summary com URLs
```

**4. terraform-destroy**
```yaml
- Checkout código
- Configurar credenciais OCI
- terraform init
- terraform destroy -auto-approve
```

**Secrets Necessários**:
- OCI_TENANCY_OCID
- OCI_USER_OCID
- OCI_FINGERPRINT
- OCI_PRIVATE_KEY
- OCI_REGION
- OCI_COMPARTMENT_ID
- SSH_PUBLIC_KEY
- DB_ADMIN_PASSWORD

## 🔄 Fluxo de Dados

### 1. Treinamento de Modelo

```
Developer → MLflow Client → MLflow Server
                                ↓
                          MySQL (metadata)
                                ↓
                      Object Storage (artifacts)
```

**Passos**:
1. Desenvolvedor executa script de treinamento
2. MLflow Client inicia run
3. Métricas/params salvos no MySQL
4. Modelo salvo no Object Storage
5. Run ID retornado ao desenvolvedor

### 2. Pipeline Orquestrado (Airflow)

```
DAG Upload → Object Storage
                 ↓
           Airflow Sync (5min)
                 ↓
           Airflow Scheduler
                 ↓
           Task Execution
                 ↓
           MLflow Tracking
```

**Passos**:
1. DAG enviada ao bucket via OCI CLI
2. Timer sincroniza bucket → instância
3. Scheduler detecta nova DAG
4. Tasks executadas sequencialmente
5. Resultados logados no MLflow

### 3. Servir Modelo (Predição)

```
Client → FastAPI → Model Cache?
                      ↓ (miss)
              MLflow Server
                      ↓
              Load Model
                      ↓
            Return Prediction
```

**Passos**:
1. Cliente faz POST /predict
2. FastAPI verifica cache
3. Se não em cache, busca do MLflow
4. Modelo carregado em memória
5. Predição executada
6. Resultado retornado

### 4. Visualização (Streamlit)

```
User → Streamlit UI
         ↓
    FastAPI (list models)
         ↓
    MLflow Server
         ↓
   Display Results
```

## 🔐 Segurança

### Camadas de Segurança

**1. Network Layer**
- VCN isolada
- Security Lists restritas
- Subnets públicas e privadas separadas
- NAT Gateway para subnet privada

**2. Compute Layer**
- Firewall habilitado (firewalld)
- SELinux em modo enforcing
- Acesso SSH apenas com chave privada
- Usuário opc (não root) para serviços

**3. Database Layer**
- Localizado em subnet privada
- Sem IP público
- Senha forte obrigatória
- Backup automático criptografado

**4. Application Layer**
- Serviços rodando como usuário não-privilegiado
- Variáveis sensíveis em arquivos .env
- Secrets do GitHub para CI/CD

**5. Storage Layer**
- Buckets sem acesso público
- Versionamento habilitado
- Acesso via IAM policies

### Princípios de Segurança

**Least Privilege**
- Cada serviço tem apenas as permissões necessárias
- Usuários específicos por aplicação

**Defense in Depth**
- Múltiplas camadas de segurança
- Falha em uma camada não compromete todo sistema

**Encryption**
- Dados em trânsito: HTTPS (recomendado adicionar)
- Dados em repouso: Criptografia OCI nativa

## 📊 Monitoramento e Observabilidade

### Logs

**Systemd Journals**:
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

**Application Logs**:
- MLflow: Métricas na própria UI
- Airflow: Logs de tasks na UI
- FastAPI: Stdout capturado por systemd

### Métricas Importantes

**Infraestrutura**:
- CPU usage por instância
- Memória disponível
- Espaço em disco
- Largura de banda de rede

**Aplicação**:
- Número de experimentos MLflow
- DAGs executadas com sucesso/falha
- Tempo de resposta da API
- Modelos em produção

### Health Checks

**MLflow**: `http://<ip>:5000/health`
**Airflow**: `http://<ip>:8080/health`
**FastAPI**: `http://<ip>:8000/`

## 💰 Otimização de Custos

### Recursos Always Free Elegíveis

- 2x VM.Standard.E2.1.Micro (AMD)
- 4x VM.Standard.A1.Flex com 24GB RAM total (ARM)
- 200GB Block Storage
- 10GB Object Storage

### Recomendações

**Para Desenvolvimento**:
- Use shapes Always Free
- Agende desligamento noturno
- Use Autonomous Database Free Tier

**Para Produção**:
- Shapes flex para escalabilidade
- Reserved Instances para desconto
- Monitore usage com Cost Analysis

## 🚀 Escalabilidade

### Escalar Verticalmente

```hcl
# Aumentar recursos das instâncias
instance_ocpus = 4
instance_memory_gb = 32
```

### Escalar Horizontalmente

**MLflow**: Adicionar Load Balancer + múltiplas instâncias
**Airflow**: Migrar para CeleryExecutor + workers
**API**: Load Balancer + Auto Scaling

### Alta Disponibilidade

- Multi-AD deployment
- Load Balancers
- Database failover
- Object Storage replicação

---

**Documentação mantida por**: Pablo Serra  
**Última revisão**: Novembro 2025
