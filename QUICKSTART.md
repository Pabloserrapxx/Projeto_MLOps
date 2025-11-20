# Quick Start Guide

Este é um guia rápido para começar com o projeto MLOps OCI.

## ⚡ Deploy Rápido (5 minutos)

### 1. Pré-requisitos

- [ ] Conta Oracle Cloud ativa
- [ ] Conta GitHub
- [ ] Credenciais OCI (API Key)
- [ ] Par de chaves SSH

### 2. Configuração GitHub

1. **Fork este repositório**

2. **Adicionar Secrets** (Settings > Secrets > Actions):
   - `OCI_TENANCY_OCID`
   - `OCI_USER_OCID`
   - `OCI_FINGERPRINT`
   - `OCI_PRIVATE_KEY`
   - `OCI_REGION`
   - `OCI_COMPARTMENT_ID`
   - `SSH_PUBLIC_KEY`
   - `DB_ADMIN_PASSWORD`

### 3. Deploy

```bash
git clone <seu-fork>
cd Projeto_MLOps
git push origin main
```

GitHub Actions irá automaticamente provisionar toda a infraestrutura!

### 4. Acessar Serviços (após 10-15 minutos)

Veja os outputs no GitHub Actions:

- **MLflow**: `http://<ip>:5000`
- **Airflow**: `http://<ip>:8080` (admin/admin)
- **FastAPI**: `http://<ip>:8000/docs`
- **Streamlit**: `http://<ip>:8501`

## 📖 Próximos Passos

- Ler [Setup Guide](docs/setup-guide.md) para detalhes
- Ver [Architecture](docs/architecture.md) para entender a infraestrutura
- Consultar [Troubleshooting](docs/troubleshooting.md) se tiver problemas

## 🆘 Ajuda Rápida

**Problema**: Deploy falhou  
**Solução**: Verifique os logs no GitHub Actions e consulte troubleshooting.md

**Problema**: Não consigo acessar serviços  
**Solução**: Aguarde 10-15 minutos após deploy, serviços ainda estão inicializando

**Problema**: Senha do banco inválida  
**Solução**: Use senha com mínimo 8 caracteres, incluindo maiúsculas, minúsculas e números
