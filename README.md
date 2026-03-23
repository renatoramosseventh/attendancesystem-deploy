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
TOKEN=ghp_xxx DOCKER_USER=usuario DOCKER_PASS=dckr_pat_xxx \
bash <(curl -fsSL https://raw.githubusercontent.com/renatoramosseventh/attendancesystem-deploy/main/install.sh)
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
git clone https://github.com/renatoramosseventh/attendancesystem-deploy
attendancesystem
cd attendancesystem

# 2. Edite as configurações
nano .env.prod        # ajuste IPs e portas
nano .env.registry    # credenciais Docker Hub (já preenchido pelo install.sh)

# 3. Suba o ambiente
make install
```

---

## Comandos disponíveis

| Comando | Descrição |
|---|---|
| `make install` | Sobe **todo** o ambiente (infra + app) |
| `make update` | Remove imagens do projeto e sobe novamente |
| `make infra` | Sobe apenas o banco de dados (MongoDB) |
| `make app` | Sobe apenas a aplicação |
| `make nuke-project` | Remove containers, volumes e imagens do projeto |
| `make nuke` | ⚠️ Remove **tudo** (containers, volumes, imagens) |

---

## Atualização

Para atualizar o sistema para uma nova versão:

```bash
cd attendancesystem
git pull          # baixa novos arquivos
make update       # limpa imagens antigas e sobe com a versão atualizada
```

---

## Suporte

Em caso de problemas, entre em contato com o suporte.