# 🚀 AttendanceSystem — Instalação

## Pré-requisitos

Antes de começar, certifique-se de que a máquina possui:

| Ferramenta | Como instalar |
|---|---|
| Docker + Docker Compose v2 | https://docs.docker.com/engine/install/ |
| Git | `sudo apt install git` |
| Make | `sudo apt install make` |

---

## Instalação (recomendada)

Execute o comando abaixo no terminal da máquina de destino:

```bash
curl -fsSL https://bitbucket.org/seventh-ltda/attendancesystem-deploy/raw/main/install.sh | bash
```

O instalador irá:
1. ✅ Verificar as dependências
2. 📥 Baixar os arquivos do projeto
3. ❓ Fazer perguntas sobre IPs e portas da sua rede
4. ⚙️ Gerar os arquivos de configuração automaticamente
5. 🚀 Subir o ambiente

---

## Instalação manual (alternativa)

Se preferir configurar manualmente:

```bash
# 1. Clone o repositório
git clone https://attendancesystem-deploy-readonly:APP_PASSWORD@bitbucket.org/seventh-ltda/attendancesystem-deploy.git attendancesystem
cd attendancesystem

# 2. Edite as configurações
nano .env.prod        # ajuste IPs e portas
nano .env.registry    # credenciais Docker Hub (já preenchido pelo install.sh)

# 3. Suba o ambiente
make up
```

---

## Comandos disponíveis

| Comando | Descrição |
|---|---|
| `make up` | Sobe **todo** o ambiente (infra + app) |
| `make infra` | Sobe apenas o banco de dados (MongoDB) |
| `make app` | Sobe apenas a aplicação |
| `make nuke` | ⚠️ Remove **tudo** (containers, volumes, imagens) |

---

## Atualização

Para atualizar o sistema para uma nova versão:

```bash
cd attendancesystem
make nuke         # limpa o ambiente anterior
git pull          # baixa novos arquivos
make up           # sobe com a versão atualizada
```

---

## Suporte

Em caso de problemas, entre em contato com o suporte.