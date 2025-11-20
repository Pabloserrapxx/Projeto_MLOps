# 🚀 Arquitetura Completa de MLOps na Oracle Cloud com Terraform e GitHub Actions

Este projeto implementa uma arquitetura completa de MLOps na Oracle Cloud Infrastructure (OCI), integrando as principais ferramentas do ecossistema de Machine Learning com automação de infraestrutura e deploy.

![MLOps Architecture](docs/architecture-diagram.png)

## 📌 Tecnologias Utilizadas

| Tecnologia | Descrição |
|------------|-----------|
| **Terraform** | Provisionamento da infraestrutura como código (IaC) |
| **GitHub Actions** | Pipeline de CI/CD para deploy automatizado |
| **MLflow** | Rastreamento de experimentos e modelos |
| **Airflow** | Orquestração de pipelines de machine learning |
| **FastAPI** | Servidor REST para servir modelos |
| **Streamlit** | Interface interativa para visualização de resultados |
| **Flask** | Servidor REST para a API de predição |
| **Docker** | Containerização da aplicação de backend |
| **MySQL** | Armazenamento de metadados (MLflow e Airflow) |
| **OCI Object Storage** | Repositório de modelos e DAGs |
| **OCI Compute** | Instâncias virtuais para serviços |
| **OCI VCN** | Rede virtual isolada |

## ⚙️ Visão Geral da Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                      Oracle Cloud Infrastructure                 │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                Virtual Cloud Network (VCN)                  │ │
│  │                                                              │ │
│  │  ┌──────────────────┐  ┌──────────────────┐               │ │
│  │  │  Public Subnet   │  │  Private Subnet  │               │ │
│  │  │                  │  │                  │               │ │
│  │  │  ┌────────────┐  │  │  ┌────────────┐ │               │ │
│  │  │  │  MLflow    │  │  │  │   MySQL    │ │               │ │
│  │  │  │  Instance  │◄─┼──┼──│  Database  │ │               │ │
│  │  │  └────────────┘  │  │  └────────────┘ │               │ │
│  │  │        ▲         │  │                  │               │ │
│  │  │  ┌────────────┐  │  └──────────────────┘               │ │
│  │  │  │  Airflow   │  │                                      │ │
│  │  │  │  Instance  │◄─┼──────────────────────────────┐      │ │
│  │  │  └────────────┘  │                               │      │ │
│  │  │        ▲         │                               │      │ │
│  │  │  ┌────────────┐  │                               │      │ │
│  │  │  │FastAPI/UI  │  │                               │      │ │
│  │  │  │  Instance  │  │                               │      │ │
│  │  │  └────────────┘  │                               │      │ │
│  │  └──────────────────┘                               │      │ │
│  └─────────────────────────────────────────────────────┼──────┘ │
│                                                         │        │
│  ┌──────────────────────────────────────────────────┐  │        │
│  │           OCI Object Storage                     │  │        │
│  │  ┌─────────────────┐  ┌─────────────────┐       │  │        │
│  │  │ MLflow Bucket   │  │ Airflow Bucket  │       │◄─┘        │
│  │  │  (Artifacts)    │  │     (DAGs)      │       │           │
│  │  └─────────────────┘  └─────────────────┘       │           │
│  └──────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### Componentes Principais

| Componente | Tecnologia | Função Principal | Recursos OCI |
|------------|------------|------------------|--------------|
| **Servidor de Tracking** | MLflow (Compute) | Registro e versionamento de experimentos | VM.Standard.E4.Flex (2 OCPUs, 16GB RAM) |
| **Orquestrador** | Airflow (Compute) | Agendamento e execução das DAGs | VM.Standard.E4.Flex (2 OCPUs, 16GB RAM) |
| **API/Interface** | FastAPI + Streamlit (Compute) | Disponibilização dos modelos | VM.Standard.E4.Flex (2 OCPUs, 16GB RAM) |
| **Banco de Dados** | MySQL Database System | Metadados (MLflow e Airflow) | MySQL.VM.Standard.E4.1.8GB |
| **Armazenamento** | Object Storage | Artefatos MLflow e DAGs Airflow | 2 Buckets |
| **Rede** | VCN | Isolamento e segurança | VCN com subnets públicas/privadas |

## 🧩 Componentes da Infraestrutura

### 1. **Virtual Cloud Network (VCN)**
- **Subnet Pública**: Hosts para MLflow, Airflow e API com acesso à internet
- **Subnet Privada**: MySQL Database isolado
- **Internet Gateway**: Acesso externo para subnet pública
- **NAT Gateway**: Acesso internet para subnet privada
- **Service Gateway**: Acesso a serviços OCI (Object Storage)
- **Security Lists**: Firewall para portas específicas (22, 5000, 8080, 8000, 8501, 3306)

### 2. **Compute Instances**
Todas as instâncias executam Oracle Linux 8 com scripts de inicialização automatizados.

#### MLflow Instance
- **Shape**: VM.Standard.E4.Flex (2 OCPUs, 16GB RAM)
- **Função**: Servidor de tracking MLflow
- **Porta**: 5000
- **Configuração**: Conectado ao MySQL e Object Storage

#### Airflow Instance
- **Shape**: VM.Standard.E4.Flex (2 OCPUs, 16GB RAM)
- **Função**: Orquestração de pipelines
- **Porta**: 8080
- **Configuração**: LocalExecutor, sync automático de DAGs do Object Storage

#### API Instance
- **Shape**: VM.Standard.E4.Flex (2 OCPUs, 16GB RAM)
- **Função**: Servir modelos via FastAPI e interface Streamlit
- **Portas**: 8000 (FastAPI), 8501 (Streamlit)

### 3. **MySQL Database System**
- **Shape**: MySQL.VM.Standard.E4.1.8GB
- **Storage**: 50GB
- **Databases**: `mlflow` e `airflow`
- **Backup**: Habilitado (retenção de 7 dias)

### 4. **Object Storage**
- **MLflow Bucket**: Armazena modelos treinados e artefatos
- **Airflow Bucket**: Contém scripts de pipeline (DAGs)
- **Versionamento**: Habilitado em ambos

## 📋 Pré-requisitos

### OCI Account
1. Conta ativa na Oracle Cloud Infrastructure
2. Tenancy OCID
3. User OCID com permissões adequadas
4. Compartment OCID onde os recursos serão criados

### Credenciais OCI
1. API Key gerada (chave privada e fingerprint)
2. Par de chaves SSH para acesso às instâncias

### Ferramentas Locais (para desenvolvimento)
```bash
# Terraform
terraform --version  # >= 1.6.0

# OCI CLI (opcional)
oci --version

# Git
git --version

# Docker
docker --version
```

## 🚀 Como Usar

### 1. Clonar o Repositório

```bash
git clone https://github.com/Pabloserrapxx/Projeto_MLOps.git
cd Projeto_MLOps
```

### 2. Configurar GitHub Secrets

Acesse `Settings > Secrets and variables > Actions` no seu repositório e adicione:

| Secret Name | Descrição | Como Obter |
|-------------|-----------|------------|
| `OCI_TENANCY_OCID` | OCID do Tenancy | Console OCI > Profile > Tenancy |
| `OCI_USER_OCID` | OCID do usuário | Console OCI > Profile > User Settings |
| `OCI_FINGERPRINT` | Fingerprint da API Key | Console OCI > API Keys |
| `OCI_PRIVATE_KEY` | Chave privada PEM (conteúdo completo) | Arquivo `.pem` gerado |
| `OCI_REGION` | Região (ex: us-ashburn-1) | Escolha da região |
| `OCI_COMPARTMENT_ID` | OCID do compartment | Console OCI > Identity > Compartments |
| `SSH_PUBLIC_KEY` | Chave pública SSH | `cat ~/.ssh/id_rsa.pub` |
| `DB_ADMIN_PASSWORD` | Senha do MySQL (mín. 8 caracteres) | Definir senha segura |

### 3. Deploy via GitHub Actions

#### Deploy Automático (Push to Main)
```bash
git add .
git commit -m "Deploy MLOps infrastructure"
git push origin main
```

O GitHub Actions irá automaticamente:
- Validar código Terraform
- Executar `terraform plan`
- Aplicar `terraform apply` (se push na branch main)

#### Deploy Manual

1. Acesse a aba `Actions` no GitHub
2. Selecione o workflow `Deploy MLOps Infrastructure to OCI`
3. Clique em `Run workflow`
4. Escolha a ação: `plan`, `apply`, ou `destroy`

### 4. Deploy Local (Alternativo)

```bash
# Navegar para o diretório terraform
cd terraform

# Criar arquivo terraform.tfvars
cat > terraform.tfvars <<EOF
tenancy_ocid       = "ocid1.tenancy.oc1..xxx"
user_ocid          = "ocid1.user.oc1..xxx"
fingerprint        = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
private_key_path   = "~/.oci/oci_api_key.pem"
region             = "us-ashburn-1"
compartment_id     = "ocid1.compartment.oc1..xxx"
ssh_public_key     = "ssh-rsa AAAAB3NzaC1yc2E..."
db_admin_password  = "SuaSenhaSegura123!"
EOF

# Inicializar Terraform
terraform init

# Validar configuração
terraform validate

# Planejar infraestrutura
terraform plan

# Aplicar (criar recursos)
terraform apply

# Destruir (remover todos os recursos)
terraform destroy
```

## 📊 Acessando os Serviços

Após o deploy (aguarde 5-10 minutos para inicialização completa):

### MLflow Tracking Server
```
http://<mlflow_public_ip>:5000
```
- Visualizar experimentos
- Comparar métricas
- Registrar modelos

### Airflow Web UI
```
http://<airflow_public_ip>:8080
```
- **Username**: `admin`
- **Password**: `admin`
- Gerenciar DAGs
- Monitorar execuções

### FastAPI Documentation
```
http://<api_public_ip>:8000/docs
```
- Testar endpoints
- Ver especificação OpenAPI
- Fazer predições

### Streamlit Dashboard
```
http://<api_public_ip>:8501
```
- Interface visual
- Fazer predições interativas
- Visualizar métricas

### Frontend e Backend (Local)

Para rodar o frontend e o backend localmente:

**Backend:**
```bash
cd backend
docker build -t iris-prediction-api .
docker run -p 5000:5000 iris-prediction-api
```
A API estará disponível em `http://127.0.0.1:5000`.

**Frontend:**
Abra o arquivo `frontend/index.html` em seu navegador.

## 🔄 Workflow CI/CD

### Jobs do GitHub Actions

1. **terraform-validation**: Valida formatação e sintaxe
2. **terraform-plan**: Gera plano de execução (PRs)
3. **terraform-apply**: Aplica mudanças (branch main)
4. **terraform-destroy**: Destrói infraestrutura (manual)

## 📁 Estrutura do Projeto

```
Projeto_MLOps/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions workflow
├── terraform/
│   ├── provider.tf             # Configuração do provider OCI
│   ├── variables.tf            # Variáveis de entrada
│   ├── outputs.tf              # Outputs da infraestrutura
│   ├── network.tf              # VCN, subnets, gateways
│   ├── compute.tf              # Instâncias EC2
│   ├── database.tf             # MySQL Database System
│   └── storage.tf              # Object Storage buckets
├── scripts/
│   ├── mlflow_init.sh          # Script de inicialização MLflow
│   ├── airflow_init.sh         # Script de inicialização Airflow
│   └── api_init.sh             # Script de inicialização API/Streamlit
├── dags/
│   └── example_dag.py          # Exemplo de DAG Airflow
├── backend/
│   ├── app.py                  # Flask API
│   ├── requirements.txt        # Python dependencies
│   └── Dockerfile              # Dockerfile for backend
├── frontend/
│   ├── index.html              # HTML file
│   ├── style.css               # CSS file
│   └── script.js               # JavaScript file
├── app/
│   ├── main.py                 # Aplicação FastAPI (gerada na instância)
│   └── streamlit_app.py        # Dashboard Streamlit (gerada na instância)
├── docs/
│   ├── architecture.md         # Documentação da arquitetura
│   ├── setup-guide.md          # Guia de configuração
│   └── troubleshooting.md      # Resolução de problemas
└── README.md                   # Este arquivo
```

## 🛠️ Fluxo de Trabalho MLOps

### 1. Desenvolvimento do Modelo

```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier

# Configurar tracking
mlflow.set_tracking_uri("http://<mlflow_ip>:5000")
mlflow.set_experiment("my-experiment")

# Treinar modelo
with mlflow.start_run():
    model = RandomForestClassifier()
    model.fit(X_train, y_train)
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
```

### 2. Orquestração com Airflow

Crie uma DAG em `dags/training_pipeline.py`:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def train_model():
    # Código de treinamento
    pass

def evaluate_model():
    # Código de avaliação
    pass

dag = DAG(
    'ml_training_pipeline',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily'
)

train = PythonOperator(
    task_id='train_model',
    python_callable=train_model,
    dag=dag
)

evaluate = PythonOperator(
    task_id='evaluate_model',
    python_callable=evaluate_model,
    dag=dag
)

train >> evaluate
```

Upload para OCI:
```bash
oci os object put --bucket-name airflow-dags --file dags/training_pipeline.py
```

### 3. Deploy do Modelo

```python
# Registrar modelo no MLflow
mlflow.register_model("runs:/<run_id>/model", "MyModel")

# Promover para produção
client = mlflow.tracking.MlflowClient()
client.transition_model_version_stage(
    name="MyModel",
    version=1,
    stage="Production"
)
```

### 4. Servir Modelo via API

```python
import requests

# Fazer predição
response = requests.post(
    "http://<api_ip>:8000/predict/MyModel/Production",
    json={"data": [[5.1, 3.5, 1.4, 0.2]]}
)

print(response.json())
# {"predictions": [0], "model_name": "MyModel", "model_version": "Production"}
```

## 🔒 Segurança

### Network Security
- Subnet privada para banco de dados
- Security Lists restritivas
- NAT Gateway para acesso controlado à internet

### Credentials Management
- Senhas armazenadas em GitHub Secrets
- Chaves SSH para acesso às instâncias
- API Keys OCI com least privilege

### Best Practices
- Atualize regularmente as dependências
- Use senhas fortes para o MySQL
- Restrinja acesso SSH por IP quando possível
- Habilite MFA na conta OCI

## 💰 Estimativa de Custos

Custos mensais estimados (região us-ashburn-1):

| Recurso | Quantidade | Custo Estimado |
|---------|------------|----------------|
| Compute VM.Standard.E4.Flex (2 OCPUs) | 3x | ~$88/mês |
| MySQL Database System | 1x | ~$90/mês |
| Object Storage (50GB) | 2x buckets | ~/mês |
| VCN, Gateways | 1x | Grátis* |
| **Total Estimado** | | **~79/mês** |

*Alguns recursos de rede são gratuitos no Free Tier

### Reduzir Custos
- Use Free Tier: 2x VM.Standard.E2.1.Micro Always Free
- Reduza OCPUs para 1 quando possível
- Use Autonomous Database Free Tier
- Agende desligamento de instâncias em horários ociosos

## 🐛 Troubleshooting

### Serviços não iniciam após deploy

**Problema**: Services não respondem nos endpoints.

**Solução**:
```bash
# SSH na instância
ssh -i ~/.ssh/id_rsa opc@<instance_ip>

# Verificar status dos serviços
sudo systemctl status mlflow       # Para MLflow
sudo systemctl status airflow-webserver  # Para Airflow
sudo systemctl status fastapi      # Para FastAPI

# Ver logs
sudo journalctl -u mlflow -n 100
sudo journalctl -u airflow-webserver -n 100
```

### Erro de conexão com MySQL

**Problema**: MLflow/Airflow não conectam ao banco.

**Solução**:
```bash
# Testar conexão
mysql -h <db_endpoint> -u admin -p

# Verificar security list
# Certifique-se de que a porta 3306 está aberta entre subnets
```

### DAGs não aparecem no Airflow

**Problema**: DAGs enviados ao bucket não aparecem.

**Solução**:
```bash
# Verificar sincronização
ssh opc@<airflow_ip>
/home/opc/sync_dags.sh

# Verificar timer
sudo systemctl status airflow-dag-sync.timer
```

## 📚 Recursos Adicionais

### Documentação
- [Oracle Cloud Infrastructure](https://docs.oracle.com/en-us/iaas/Content/home.htm)
- [Terraform OCI Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [Apache Airflow](https://airflow.apache.org/docs/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Streamlit](https://docs.streamlit.io/)

### Próximos Passos
- [ ] Implementar monitoramento com OCI Monitoring
- [ ] Adicionar alertas com OCI Notifications
- [ ] Configurar Load Balancer para alta disponibilidade
- [ ] Implementar autoscaling de compute instances
- [ ] Adicionar testes automatizados
- [ ] Configurar backup automático de buckets
- [ ] Implementar CI/CD para modelos (MLOps Level 2)

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## ✨ Autores

- **Pablo Serra** - [@Pabloserrapxx](https://github.com/Pabloserrapxx)

## 🙏 Agradecimentos

- Comunidade MLflow
- Comunidade Apache Airflow
- Oracle Cloud Infrastructure
- HashiCorp Terraform

---

**⚠️ Nota**: Este é um projeto educacional/demonstrativo. Para ambientes de produção, considere adicionar:
- HTTPS com certificados SSL
- Autenticação robusta (OAuth2, LDAP)
- Backup e disaster recovery
- Monitoramento e observabilidade
- Alta disponibilidade e redundância