# Guia de Configuração - MLOps na Oracle Cloud

Este guia detalha o processo completo de configuração da infraestrutura MLOps na Oracle Cloud Infrastructure.

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Configuração da Conta OCI](#configuração-da-conta-oci)
3. [Configuração de Credenciais](#configuração-de-credenciais)
4. [Configuração do GitHub](#configuração-do-github)
5. [Deploy da Infraestrutura](#deploy-da-infraestrutura)
6. [Verificação e Testes](#verificação-e-testes)

## 🔧 Pré-requisitos

### Conta Oracle Cloud

1. **Criar conta OCI** (se ainda não tiver):
   - Acesse: https://cloud.oracle.com/
   - Clique em "Start for free"
   - Preencha os dados e ative a conta

2. **Free Tier disponível**:
   - 2x VM.Standard.E2.1.Micro (Always Free)
   - 200GB Block Storage
   - 10GB Object Storage
   - Autonomous Database

### Ferramentas Necessárias

```bash
# Terraform
winget install HashiCorp.Terraform

# Git
winget install Git.Git

# OCI CLI (opcional, mas recomendado)
# Download: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
```

## ⚙️ Configuração da Conta OCI

### 1. Criar Compartment

Um compartment é um container lógico para organizar recursos.

1. Acesse o Console OCI
2. Menu hamburger > Identity & Security > Compartments
3. Clique em "Create Compartment"
4. Preencha:
   - **Name**: `mlops-compartment`
   - **Description**: `Compartment for MLOps project`
   - **Parent Compartment**: (root) ou outro de sua escolha
5. Clique em "Create Compartment"
6. **Copie o OCID** do compartment criado

### 2. Obter OCIDs Necessários

#### Tenancy OCID
1. Menu hamburger > Profile (canto superior direito)
2. Clique em "Tenancy: <nome>"
3. Copie o **OCID** na seção "Tenancy Information"

#### User OCID
1. Menu hamburger > Profile > User Settings
2. Copie o **OCID** na seção "User Information"

### 3. Criar API Key

1. Menu hamburger > Profile > User Settings
2. Na seção "Resources" (lado esquerdo), clique em "API Keys"
3. Clique em "Add API Key"
4. Selecione "Generate API Key Pair"
5. Clique em "Download Private Key" (salve como `oci_api_key.pem`)
6. Clique em "Download Public Key" (opcional, backup)
7. Clique em "Add"
8. **Copie o Fingerprint** exibido na tela

#### Mover chave privada (Linux/Mac):
```bash
mkdir -p ~/.oci
mv ~/Downloads/oci_api_key.pem ~/.oci/
chmod 600 ~/.oci/oci_api_key.pem
```

#### Mover chave privada (Windows):
```powershell
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.oci
Move-Item -Path $env:USERPROFILE\Downloads\oci_api_key.pem -Destination $env:USERPROFILE\.oci\
```

### 4. Criar Par de Chaves SSH

Para acesso às instâncias.

#### Linux/Mac:
```bash
ssh-keygen -t rsa -b 4096 -C "mlops-key" -f ~/.ssh/mlops_key
cat ~/.ssh/mlops_key.pub  # Copie esta chave pública
```

#### Windows (PowerShell):
```powershell
ssh-keygen -t rsa -b 4096 -C "mlops-key" -f $env:USERPROFILE\.ssh\mlops_key
Get-Content $env:USERPROFILE\.ssh\mlops_key.pub  # Copie esta chave pública
```

## 🔐 Configuração de Credenciais

### Configurar OCI CLI (Recomendado)

```bash
oci setup config
```

Responda as perguntas:
- **Enter a location for your config**: (pressione Enter para padrão)
- **Enter a user OCID**: cole o User OCID
- **Enter a tenancy OCID**: cole o Tenancy OCID
- **Enter a region**: ex: `us-ashburn-1`
- **Generate a new API signing RSA key pair?**: `n` (já criamos)
- **Enter the location of your API signing private key file**: `~/.oci/oci_api_key.pem`

Teste a configuração:
```bash
oci iam region list
```

## 🐙 Configuração do GitHub

### 1. Fork ou Clone o Repositório

```bash
git clone https://github.com/Pabloserrapxx/Projeto_MLOps.git
cd Projeto_MLOps
```

### 2. Configurar Secrets no GitHub

1. Acesse seu repositório no GitHub
2. Vá em **Settings** > **Secrets and variables** > **Actions**
3. Clique em "New repository secret" para cada um dos seguintes:

#### Secrets Necessários:

| Nome | Valor | Onde Encontrar |
|------|-------|----------------|
| `OCI_TENANCY_OCID` | `ocid1.tenancy.oc1..xxx` | Console OCI > Profile > Tenancy |
| `OCI_USER_OCID` | `ocid1.user.oc1..xxx` | Console OCI > Profile > User Settings |
| `OCI_FINGERPRINT` | `xx:xx:xx:...` | Console OCI > User Settings > API Keys |
| `OCI_PRIVATE_KEY` | Conteúdo do arquivo `.pem` | Abra `~/.oci/oci_api_key.pem` |
| `OCI_REGION` | `us-ashburn-1` | Sua região escolhida |
| `OCI_COMPARTMENT_ID` | `ocid1.compartment.oc1..xxx` | Console OCI > Compartments |
| `SSH_PUBLIC_KEY` | `ssh-rsa AAAAB3...` | Conteúdo de `~/.ssh/mlops_key.pub` |
| `DB_ADMIN_PASSWORD` | `SuaSenha123!` | Crie uma senha forte (mín. 8 caracteres) |

#### Como adicionar OCI_PRIVATE_KEY:

1. Abra o arquivo `~/.oci/oci_api_key.pem` em um editor de texto
2. Copie **todo o conteúdo** incluindo as linhas:
   ```
   -----BEGIN PRIVATE KEY-----
   ...conteúdo...
   -----END PRIVATE KEY-----
   ```
3. Cole no campo "Value" do secret `OCI_PRIVATE_KEY`

### 3. Criar Ambiente de Produção (Opcional, mas recomendado)

1. Vá em **Settings** > **Environments**
2. Clique em "New environment"
3. Nome: `production`
4. (Opcional) Configure proteção:
   - Marque "Required reviewers" e adicione revisores
   - Configure "Wait timer" se desejar delay antes do deploy

## 🚀 Deploy da Infraestrutura

### Opção 1: Deploy via GitHub Actions (Recomendado)

1. Faça commit e push para branch `main`:
   ```bash
   git add .
   git commit -m "Initial infrastructure setup"
   git push origin main
   ```

2. Monitore o workflow:
   - Acesse a aba **Actions** no GitHub
   - Clique no workflow em execução
   - Acompanhe os logs em tempo real

3. Após conclusão (~15-20 minutos):
   - Verifique o "Summary" com URLs dos serviços
   - Aguarde mais 5-10 minutos para inicialização completa

### Opção 2: Deploy Local

1. Navegue até o diretório terraform:
   ```bash
   cd terraform
   ```

2. Crie arquivo `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edite `terraform.tfvars` com suas credenciais

4. Execute o Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. Confirme com `yes` quando solicitado

6. Aguarde a conclusão (~15-20 minutos)

## ✅ Verificação e Testes

### 1. Obter IPs das Instâncias

Via Terraform:
```bash
cd terraform
terraform output
```

Via Console OCI:
1. Menu > Compute > Instances
2. Anote os IPs públicos das 3 instâncias

### 2. Testar MLflow

```bash
curl http://<mlflow_ip>:5000/health
```

Acesse no navegador:
```
http://<mlflow_ip>:5000
```

### 3. Testar Airflow

Acesse no navegador:
```
http://<airflow_ip>:8080
```

Login:
- **Username**: `admin`
- **Password**: `admin`

### 4. Testar FastAPI

```bash
curl http://<api_ip>:8000/
```

Documentação interativa:
```
http://<api_ip>:8000/docs
```

### 5. Testar Streamlit

Acesse no navegador:
```
http://<api_ip>:8501
```

### 6. Testar SSH nas Instâncias

```bash
ssh -i ~/.ssh/mlops_key opc@<instance_ip>
```

Verificar logs:
```bash
sudo journalctl -u mlflow -n 50
sudo journalctl -u airflow-webserver -n 50
sudo journalctl -u fastapi -n 50
```

## 🔄 Upload de DAG para Airflow

### Via OCI CLI:

```bash
# Configure OCI CLI com seu profile
oci os object put \
  --bucket-name <project-name>-airflow-dags-<environment> \
  --file dags/example_iris_pipeline.py \
  --name example_iris_pipeline.py
```

### Via Console OCI:

1. Menu > Storage > Buckets
2. Clique no bucket `airflow-dags`
3. Clique em "Upload"
4. Selecione o arquivo `dags/example_iris_pipeline.py`
5. Aguarde 5 minutos (sincronização automática)
6. Verifique em Airflow UI

## 🧪 Teste Completo do Fluxo MLOps

### 1. Treinar um Modelo com MLflow

Crie um arquivo `train.py`:

```python
import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

# Configurar MLflow
mlflow.set_tracking_uri("http://<mlflow_ip>:5000")
mlflow.set_experiment("test-experiment")

# Carregar dados
iris = load_iris()
X_train, X_test, y_train, y_test = train_test_split(
    iris.data, iris.target, test_size=0.2, random_state=42
)

# Treinar com MLflow
with mlflow.start_run():
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X_train, y_train)
    
    accuracy = accuracy_score(y_test, model.predict(X_test))
    
    mlflow.log_param("n_estimators", 100)
    mlflow.log_metric("accuracy", accuracy)
    mlflow.sklearn.log_model(model, "model")
    
    print(f"Modelo treinado com accuracy: {accuracy:.4f}")
```

Execute:
```bash
python train.py
```

### 2. Verificar no MLflow UI

1. Acesse `http://<mlflow_ip>:5000`
2. Verifique o experimento "test-experiment"
3. Clique no run criado
4. Veja métricas e artefatos

### 3. Fazer Predição via API

```bash
curl -X POST "http://<api_ip>:8000/predict/iris-classifier/1" \
  -H "Content-Type: application/json" \
  -d '{"data": [[5.1, 3.5, 1.4, 0.2]]}'
```

## 🛑 Destruir Infraestrutura

### Via GitHub Actions:

1. Vá em **Actions**
2. Selecione workflow "Deploy MLOps Infrastructure to OCI"
3. Clique em "Run workflow"
4. Selecione action: `destroy`
5. Confirme

### Via Terraform Local:

```bash
cd terraform
terraform destroy
```

Confirme com `yes`.

## 📚 Próximos Passos

- [ ] Configurar domínio personalizado
- [ ] Adicionar certificado SSL
- [ ] Implementar autenticação OAuth2
- [ ] Configurar alertas de monitoramento
- [ ] Criar mais DAGs customizadas
- [ ] Implementar CI/CD para modelos

## 🆘 Suporte

Se encontrar problemas:

1. Consulte [troubleshooting.md](troubleshooting.md)
2. Verifique logs das instâncias via SSH
3. Consulte documentação oficial da OCI
4. Abra uma issue no GitHub

---

**Criado por**: Pablo Serra  
**Última atualização**: Novembro 2025
