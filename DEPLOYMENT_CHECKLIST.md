# ✅ Checklist Final de Configuração

## 🔐 1. GitHub Secrets (OBRIGATÓRIO)
- [x] Você já configurou as 8 secrets no GitHub

## 📝 2. Configurações Locais (Para desenvolvimento local)

### 2.1. Arquivo `terraform.tfvars` (NÃO COMITAR)
Crie um arquivo `terraform/terraform.tfvars` para testar localmente:

```hcl
tenancy_ocid       = "ocid1.tenancy.oc1..aaaaaaaa..."
user_ocid          = "ocid1.user.oc1..aaaaaaaa..."
fingerprint        = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
private_key_path   = "~/.oci/oci_api_key.pem"
region             = "sa-saopaulo-1"
compartment_id     = "ocid1.compartment.oc1..aaaaaaaa..."
ssh_public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."
db_admin_password  = "SuaSenhaSegura123!"
```

⚠️ **Este arquivo está no `.gitignore` e NÃO será commitado.**

### 2.2. Chave Privada OCI Local
Coloque sua chave privada em `~/.oci/oci_api_key.pem`:

```bash
mkdir -p ~/.oci
# Cole sua chave privada no arquivo
chmod 600 ~/.oci/oci_api_key.pem
```

## 🚀 3. Antes do Primeiro Deploy

### 3.1. Verificar Cotas da OCI
- [ ] Verifique se você tem cotas disponíveis para:
  - **3 instâncias Compute** (VM.Standard.E4.Flex)
  - **1 MySQL Database** (MySQL.VM.Standard.E4.1.8GB)
  - **2 Object Storage Buckets**
  - **1 VCN**

**Como verificar:**
- Acesse o Console da OCI
- Vá em **Governance & Administration** > **Limits, Quotas and Usage**
- Verifique os limites da sua região

### 3.2. Permissões do Usuário
Seu usuário OCI precisa ter permissões para:
- [ ] Gerenciar Compute Instances
- [ ] Gerenciar VCN e Network
- [ ] Gerenciar MySQL Database
- [ ] Gerenciar Object Storage
- [ ] Criar Security Lists e Route Tables

**Como verificar:**
- Vá em **Identity & Security** > **Policies**
- Verifique se há policies que concedem acesso ao seu compartment

### 3.3. Limite de Gastos
⚠️ **IMPORTANTE:** Este projeto cria recursos pagos na OCI:
- 3 instâncias Compute (2 OCPUs, 16GB RAM cada)
- 1 MySQL Database
- Object Storage (cobrado por armazenamento)

**Estimativa de custo:** ~$150-200/mês (varia por região)

Para evitar gastos inesperados:
- [ ] Configure **Budget Alerts** no Console da OCI
- [ ] Use o **Cost Analysis** para monitorar gastos
- [ ] Execute `terraform destroy` quando não estiver usando

## 🔄 4. Primeiro Deploy

### 4.1. Via GitHub Actions (Recomendado)
Após configurar as secrets:

```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

O workflow será acionado automaticamente.

### 4.2. Localmente (Opcional)
Se quiser testar localmente antes:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 🎯 5. Pós-Deploy

### 5.1. Aguarde a Inicialização
Após o deploy bem-sucedido:
- [ ] Aguarde **5-10 minutos** para os scripts de inicialização rodarem
- [ ] Os serviços serão instalados automaticamente nas instâncias

### 5.2. Acesse os Serviços
O workflow do GitHub mostrará os URLs:
- [ ] **MLflow:** `http://<ip>:5000`
- [ ] **Airflow:** `http://<ip>:8080` 
  - User: `admin`
  - Password: Verifique logs da instância ou configure no script
- [ ] **FastAPI:** `http://<ip>:8000/docs`
- [ ] **Streamlit:** `http://<ip>:8501`

### 5.3. Credenciais do Airflow
As credenciais padrão do Airflow são criadas pelo script `airflow_init.sh`:
- **User:** `admin`
- **Password:** `admin123`

⚠️ **Troque essa senha em produção!**

### 5.4. Configurar SSL/HTTPS (Recomendado para produção)
Para produção, configure:
- [ ] Um domínio próprio
- [ ] Certificado SSL (Let's Encrypt)
- [ ] Load Balancer da OCI (opcional)

## 🔍 6. Verificação de Funcionamento

### 6.1. Testar MLflow
```bash
curl http://<mlflow-ip>:5000
```

### 6.2. Testar Airflow
```bash
curl http://<airflow-ip>:8080
```

### 6.3. Testar FastAPI
```bash
curl http://<api-ip>:8000/docs
```

### 6.4. Testar Backend + Frontend Localmente
```bash
# Terminal 1 - Backend
cd app/backend
..\.venv\Scripts\Activate.ps1
uvicorn main:app --reload

# Terminal 2 - Frontend
cd app/frontend
..\.venv\Scripts\Activate.ps1
streamlit run streamlit_app.py
```

## 🛠️ 7. Manutenção

### 7.1. Atualizar Infraestrutura
Faça mudanças no Terraform e commit:
```bash
git add terraform/
git commit -m "Update infrastructure"
git push origin main
```

### 7.2. Adicionar DAGs no Airflow
Upload de DAGs para o Object Storage:
```bash
oci os object put \
  --bucket-name airflow-dags \
  --file dags/my_new_dag.py \
  --name my_new_dag.py
```

### 7.3. Destruir Infraestrutura
Quando quiser remover tudo:
```bash
# Via GitHub Actions
# Settings > Actions > Deploy MLOps Infrastructure to OCI
# Run workflow > Select "destroy"

# Ou localmente
cd terraform
terraform destroy
```

## 📚 8. Documentação Adicional

Consulte os arquivos:
- [ ] `README.md` - Visão geral do projeto
- [ ] `QUICKSTART.md` - Guia rápido de início
- [ ] `COMMANDS.md` - Comandos úteis
- [ ] `docs/architecture.md` - Arquitetura detalhada
- [ ] `docs/troubleshooting.md` - Resolução de problemas

## 🎉 Pronto!

Se você completou todos os itens acima, sua infraestrutura MLOps está pronta para uso!

**Próximos passos:**
1. Treinar um modelo e registrá-lo no MLflow
2. Criar pipelines no Airflow para automatizar o treinamento
3. Servir o modelo via FastAPI
4. Visualizar predições no Streamlit
