# GitHub Secrets Configuration Guide

Para que o pipeline de CI/CD funcione corretamente, você precisa configurar as seguintes **GitHub Secrets** no seu repositório.

## 📍 Como Configurar Secrets no GitHub

1. Vá até o seu repositório no GitHub
2. Clique em **Settings** > **Secrets and variables** > **Actions**
3. Clique em **New repository secret**
4. Adicione cada secret abaixo

---

## 🔑 Secrets Obrigatórios

### 1. **OCI_TENANCY_OCID**
- **Descrição:** OCID do seu Tenancy na Oracle Cloud
- **Formato:** `ocid1.tenancy.oc1..aaaaaaaa...`
- **Como obter:** 
  - Acesse o Console da OCI
  - Clique no seu perfil (canto superior direito)
  - Clique em **Tenancy: <nome>**
  - Copie o **OCID**

### 2. **OCI_USER_OCID**
- **Descrição:** OCID do usuário da OCI
- **Formato:** `ocid1.user.oc1..aaaaaaaa...`
- **Como obter:**
  - Acesse o Console da OCI
  - Clique no seu perfil (canto superior direito)
  - Clique em **User Settings**
  - Copie o **OCID**

### 3. **OCI_FINGERPRINT**
- **Descrição:** Fingerprint da chave API da OCI
- **Formato:** `xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx`
- **Como obter:**
  - Acesse **User Settings** no Console da OCI
  - Vá em **API Keys**
  - Copie o **Fingerprint** da chave que você criou

### 4. **OCI_PRIVATE_KEY**
- **Descrição:** Chave privada da API da OCI (formato PEM)
- **Formato:**
  ```
  -----BEGIN PRIVATE KEY-----
  MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
  -----END PRIVATE KEY-----
  ```
- **Como obter:**
  - Quando você criou a API Key no OCI Console, você baixou um arquivo `.pem`
  - Abra esse arquivo e copie **TODO** o conteúdo (incluindo as linhas BEGIN/END)
  - **⚠️ IMPORTANTE:** Cole o conteúdo completo, incluindo quebras de linha

### 5. **OCI_REGION**
- **Descrição:** Região da OCI onde os recursos serão criados
- **Formato:** `us-ashburn-1` ou `us-phoenix-1` ou `sa-saopaulo-1`
- **Exemplos:**
  - `us-ashburn-1` (EUA - Leste)
  - `us-phoenix-1` (EUA - Oeste)
  - `sa-saopaulo-1` (Brasil - São Paulo)
- **Como obter:**
  - Veja a lista completa de regiões: https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm

### 6. **OCI_COMPARTMENT_ID**
- **Descrição:** OCID do compartment onde os recursos serão criados
- **Formato:** `ocid1.compartment.oc1..aaaaaaaa...`
- **Como obter:**
  - Acesse **Identity & Security** > **Compartments** no Console da OCI
  - Selecione o compartment desejado (ou use o root)
  - Copie o **OCID**

### 7. **SSH_PUBLIC_KEY**
- **Descrição:** Chave pública SSH para acessar as instâncias EC2
- **Formato:** `ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@hostname`
- **Como obter:**
  - Se você já tem uma chave SSH: `cat ~/.ssh/id_rsa.pub`
  - Se não tem, crie uma:
    ```bash
    ssh-keygen -t rsa -b 4096 -C "seu_email@example.com"
    cat ~/.ssh/id_rsa.pub
    ```
  - Copie **toda a linha** da chave pública

### 8. **DB_ADMIN_PASSWORD**
- **Descrição:** Senha do usuário administrador do MySQL
- **Formato:** Mínimo 8 caracteres, deve conter letras, números e símbolos
- **Exemplo:** `MySecurePass123!`
- **⚠️ IMPORTANTE:** Escolha uma senha forte e segura

---

## 📋 Checklist de Configuração

Marque cada secret conforme você adiciona no GitHub:

- [ ] `OCI_TENANCY_OCID`
- [ ] `OCI_USER_OCID`
- [ ] `OCI_FINGERPRINT`
- [ ] `OCI_PRIVATE_KEY`
- [ ] `OCI_REGION`
- [ ] `OCI_COMPARTMENT_ID`
- [ ] `SSH_PUBLIC_KEY`
- [ ] `DB_ADMIN_PASSWORD`

---

## ✅ Validação

Depois de configurar todas as secrets:

1. Faça um push para a branch `main`:
   ```bash
   git add .
   git commit -m "Configure GitHub secrets"
   git push origin main
   ```

2. Verifique o status do workflow:
   - Vá até a aba **Actions** no GitHub
   - Veja se o workflow `Deploy MLOps Infrastructure to OCI` está rodando
   - Se houver erros, verifique se todas as secrets foram configuradas corretamente

---

## 🔍 Troubleshooting

### Erro: "Invalid authentication credentials"
- Verifique se `OCI_TENANCY_OCID`, `OCI_USER_OCID` e `OCI_FINGERPRINT` estão corretos
- Confirme que a `OCI_PRIVATE_KEY` está completa (incluindo BEGIN/END)

### Erro: "Compartment not found"
- Verifique se `OCI_COMPARTMENT_ID` está correto
- Confirme que seu usuário tem permissões no compartment

### Erro: "Invalid SSH key"
- Verifique se `SSH_PUBLIC_KEY` começa com `ssh-rsa` ou `ssh-ed25519`
- Confirme que não há quebras de linha no meio da chave

### Erro: "Weak database password"
- `DB_ADMIN_PASSWORD` deve ter pelo menos 8 caracteres
- Deve conter letras maiúsculas, minúsculas, números e símbolos especiais

---

## 🎯 Próximos Passos

Após configurar todas as secrets e o pipeline rodar com sucesso:

1. ✅ As instâncias OCI serão criadas automaticamente
2. ✅ MLflow, Airflow, FastAPI e Streamlit serão provisionados
3. ✅ Os URLs dos serviços aparecerão no output do workflow

**URLs esperados:**
- MLflow: `http://<mlflow-ip>:5000`
- Airflow: `http://<airflow-ip>:8080`
- FastAPI: `http://<api-ip>:8000`
- Streamlit: `http://<streamlit-ip>:8501`
