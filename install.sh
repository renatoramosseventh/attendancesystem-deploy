#!/bin/bash

# ==============================================================
#  🚀 Instalador - AttendanceSystem
#  Uso:
#  TOKEN=ghp_xxx DOCKER_USER=usuario DOCKER_PASS=dckr_pat_xxx \
#    bash <(curl -fsSL https://raw.githubusercontent.com/renatoramosseventh/attendancesystem-deploy/main/install.sh)
# ==============================================================

# ── Redireciona stdin para o terminal quando rodado via curl | bash ──
if [ -t 0 ]; then
  :
else
  exec < /dev/tty
fi

set -e

# ─── Cores ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Repositório Git ──────────────────────────────────────────
GITHUB_USER="renatoramosseventh"
REPO_NAME="attendancesystem-deploy"
INSTALL_DIR="attendancesystem"

# ══════════════════════════════════════════════════════════════
# Validar variáveis obrigatórias
# ══════════════════════════════════════════════════════════════

validate_env() {
  local errors=0

  if [ -z "$TOKEN" ]; then
    echo -e "  ${RED}✖ TOKEN não informado${NC} (token GitHub para clonar o repositório)"
    errors=$((errors + 1))
  fi

  if [ -z "$DOCKER_USER" ]; then
    echo -e "  ${RED}✖ DOCKER_USER não informado${NC} (usuário Docker Hub)"
    errors=$((errors + 1))
  fi

  if [ -z "$DOCKER_PASS" ]; then
    echo -e "  ${RED}✖ DOCKER_PASS não informado${NC} (access token Docker Hub)"
    errors=$((errors + 1))
  fi

  if [ "$errors" -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Execute o instalador assim:${NC}"
    echo ""
    echo -e "  ${BOLD}TOKEN=ghp_xxx DOCKER_USER=usuario DOCKER_PASS=dckr_pat_xxx \\${NC}"
    echo -e "  ${BOLD}  bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/install.sh)${NC}"
    echo ""
    exit 1
  fi
}

GIT_REPO="https://${TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

# ══════════════════════════════════════════════════════════════
# Funções utilitárias
# ══════════════════════════════════════════════════════════════

print_banner() {
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║        🚀  AttendanceSystem Installer        ║"
  echo "  ║              Instalação Guiada               ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

print_step() {
  echo -e "\n${BLUE}${BOLD}▶ $1${NC}"
}

print_ok() {
  echo -e "  ${GREEN}✔ $1${NC}"
}

print_warn() {
  echo -e "  ${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "  ${RED}✖ $1${NC}"
}

ask() {
  local varname="$1"
  local prompt="$2"
  local default="$3"
  local value=""

  if [ -n "$default" ]; then
    echo -ne "  ${BOLD}${prompt}${NC} ${CYAN}[padrão: ${default}]${NC}: "
  else
    echo -ne "  ${BOLD}${prompt}${NC}: "
  fi

  read -r value
  value="${value:-$default}"

  while [ -z "$value" ]; do
    echo -ne "  ${RED}Campo obrigatório.${NC} ${BOLD}${prompt}${NC}: "
    read -r value
  done

  eval "$varname=\"$value\""
}

confirm() {
  echo -ne "  ${BOLD}$1${NC} ${CYAN}[s/N]${NC}: "
  read -r resp
  [[ "$resp" =~ ^[sS]$ ]]
}

# ══════════════════════════════════════════════════════════════
# 1. Verificar dependências
# ══════════════════════════════════════════════════════════════

check_deps() {
  print_step "Verificando dependências..."

  local missing=()

  for cmd in docker git make curl; do
    if command -v "$cmd" &>/dev/null; then
      print_ok "$cmd encontrado ($(command -v "$cmd"))"
    else
      print_error "$cmd não encontrado"
      missing+=("$cmd")
    fi
  done

  if docker compose version &>/dev/null 2>&1; then
    print_ok "docker compose (plugin) encontrado"
  elif command -v docker-compose &>/dev/null; then
    print_warn "docker-compose (v1) encontrado — recomendamos atualizar para Docker Compose v2"
  else
    print_error "docker compose não encontrado"
    missing+=("docker-compose")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    print_error "Dependências faltando: ${missing[*]}"
    echo -e "  Instale-as e execute o instalador novamente."
    exit 1
  fi

  print_ok "Todas as dependências OK"
}

# ══════════════════════════════════════════════════════════════
# 2. Clonar repositório
# ══════════════════════════════════════════════════════════════

clone_repo() {
  print_step "Baixando arquivos do projeto..."

  if [ -d "$INSTALL_DIR" ]; then
    print_warn "A pasta '${INSTALL_DIR}' já existe."
    if confirm "Deseja atualizar os arquivos existentes? (git pull)"; then
      cd "$INSTALL_DIR"
      git pull
      cd ..
      print_ok "Arquivos atualizados com sucesso"
    else
      print_warn "Usando arquivos existentes sem atualizar."
    fi
  else
    git clone "$GIT_REPO" "$INSTALL_DIR"
    print_ok "Arquivos baixados em: $(pwd)/${INSTALL_DIR}"
  fi
}

# ══════════════════════════════════════════════════════════════
# 3. Coletar configurações do cliente
# ══════════════════════════════════════════════════════════════

collect_config() {
  print_step "Configuração do ambiente"
  echo -e "  ${CYAN}Responda as perguntas abaixo. Pressione ENTER para usar o valor padrão.${NC}\n"

  echo -e "  ${BOLD}── Rede ──────────────────────────────────────────${NC}"
  ask EXTERNAL_HOST "IP ou hostname desta máquina (acesso externo)" "http://192.168.1.100"
  ask INTERNAL_HOST "IP ou hostname interno (geralmente igual ao externo)" "$EXTERNAL_HOST"

  echo ""
  echo -e "  ${BOLD}── Sistema Base (legado integrado) ───────────────${NC}"
  ask SYSTEM_BASE_HOST "IP/hostname do sistema base"   "http://192.168.1.1"
  ask SYSTEM_BASE_PORT "Porta do sistema base"         "8080"

  echo ""
  echo -e "  ${BOLD}── Portas dos serviços ───────────────────────────${NC}"
  ask MONGO_PORT                                  "MongoDB"                       "27017"
  ask BACKEND_SUITE_API_EXTERNAL_PORT             "Backend Suite API"             "10101"
  ask BACKEND_PEOPLE_API_EXTERNAL_PORT            "Backend People API"            "10100"
  ask BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT  "Backend AttendanceSystem API"  "10102"
  ask BACKEND_ACCOUNT_API_EXTERNAL_PORT           "Backend Account API"           "10103"
  ask FRONTEND_SUITE_APP_EXTERNAL_PORT            "Frontend Suite"                "4200"
  ask FRONTEND_PEOPLE_APP_EXTERNAL_PORT           "Frontend People"               "4201"
  ask FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT "Frontend AttendanceSystem"     "4202"
  ask FRONTEND_ACCOUNT_APP_EXTERNAL_PORT          "Frontend Account"              "4203"
}

# ══════════════════════════════════════════════════════════════
# 4. Gerar arquivos .env
# ══════════════════════════════════════════════════════════════

generate_envs() {
  print_step "Gerando arquivos de configuração..."

  local BASE_DIR="$INSTALL_DIR"

  # ── .env.registry ─────────────────────────────────────────
  cat > "$BASE_DIR/.env.registry" <<EOF
DOCKER_USERNAME="${DOCKER_USER}"
DOCKER_PASSWORD="${DOCKER_PASS}"
EOF
  print_ok ".env.registry gerado"

  # ── Derivados calculados ───────────────────────────────────
  local SYSTEM_BASE_CONN="${SYSTEM_BASE_HOST}:${SYSTEM_BASE_PORT}"
  local KEEPALIVE_BACKEND="${EXTERNAL_HOST}:${BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT}"
  local KEEPALIVE_FRONTEND="${EXTERNAL_HOST}:${FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT}"

  # Internals = externos (simplificado)
  local BACKEND_SUITE_API_INTERNAL_PORT="$BACKEND_SUITE_API_EXTERNAL_PORT"
  local BACKEND_PEOPLE_API_INTERNAL_PORT="$BACKEND_PEOPLE_API_EXTERNAL_PORT"
  local BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT="$BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT"
  local BACKEND_ACCOUNT_API_INTERNAL_PORT="$BACKEND_ACCOUNT_API_EXTERNAL_PORT"
  local FRONTEND_SUITE_APP_INTERNAL_PORT="$FRONTEND_SUITE_APP_EXTERNAL_PORT"
  local FRONTEND_PEOPLE_APP_INTERNAL_PORT="$FRONTEND_PEOPLE_APP_EXTERNAL_PORT"
  local FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT="$FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT"
  local FRONTEND_ACCOUNT_APP_INTERNAL_PORT="$FRONTEND_ACCOUNT_APP_EXTERNAL_PORT"

  # ── .env.prod ──────────────────────────────────────────────
  cat > "$BASE_DIR/.env.prod" <<EOF
ASPNETCORE_ENVIRONMENT=Production
DOCKER_REPO=seventhltda
IMAGEM_LATEST=latest
IMAGEM_UNSTABLE_LATEST=unstable-latest
IMAGEM_DEMO_V3=demo-v3
NGINX_DEFAULT_PORT=80

# ── MongoDB ───────────────────────────────────────────────
MONGO_PORT=${MONGO_PORT}
MONGODB_CONNECTION_STRING=mongodb://mongodb:27017/suitedb
MONGODB_DATABASE=suitedb

# ── Sistema Base ──────────────────────────────────────────
SYSTEM_BASE_CONN=${SYSTEM_BASE_CONN}
SYSTEM_BASE_HOST=${SYSTEM_BASE_HOST}
SYSTEM_BASE_PORT=${SYSTEM_BASE_PORT}

# ── Hosts ─────────────────────────────────────────────────
INTERNAL_HOST=${INTERNAL_HOST}
EXTERNAL_HOST=${EXTERNAL_HOST}

# ── Backend ───────────────────────────────────────────────
BACKEND_SUITE_API_INTERNAL_PORT=${BACKEND_SUITE_API_INTERNAL_PORT}
BACKEND_SUITE_API_EXTERNAL_PORT=${BACKEND_SUITE_API_EXTERNAL_PORT}

BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT=${BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT}
BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT=${BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT}

BACKEND_PEOPLE_API_INTERNAL_PORT=${BACKEND_PEOPLE_API_INTERNAL_PORT}
BACKEND_PEOPLE_API_EXTERNAL_PORT=${BACKEND_PEOPLE_API_EXTERNAL_PORT}

BACKEND_ACCOUNT_API_INTERNAL_PORT=${BACKEND_ACCOUNT_API_INTERNAL_PORT}
BACKEND_ACCOUNT_API_EXTERNAL_PORT=${BACKEND_ACCOUNT_API_EXTERNAL_PORT}

BACKEND_ATTENDANCESYSTEM_API_APPLICATIONNAME=AttendanceSystem
BACKEND_ATTENDANCESYSTEM_API_NAME=attendancesystem-api

# ── Frontend ──────────────────────────────────────────────
FRONTEND_SUITE_APP_INTERNAL_PORT=${FRONTEND_SUITE_APP_INTERNAL_PORT}
FRONTEND_SUITE_APP_EXTERNAL_PORT=${FRONTEND_SUITE_APP_EXTERNAL_PORT}

FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT=${FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT}
FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT=${FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT}

FRONTEND_PEOPLE_APP_INTERNAL_PORT=${FRONTEND_PEOPLE_APP_INTERNAL_PORT}
FRONTEND_PEOPLE_APP_EXTERNAL_PORT=${FRONTEND_PEOPLE_APP_EXTERNAL_PORT}

FRONTEND_ACCOUNT_APP_INTERNAL_PORT=${FRONTEND_ACCOUNT_APP_INTERNAL_PORT}
FRONTEND_ACCOUNT_APP_EXTERNAL_PORT=${FRONTEND_ACCOUNT_APP_EXTERNAL_PORT}

# ── Keepalive ─────────────────────────────────────────────
KEEPALIVE_ATTENDANCE_SYSTEM_BACKEND_HOST=${KEEPALIVE_BACKEND}
KEEPALIVE_ATTENDANCE_SYSTEM_FRONTEND_HOST=${KEEPALIVE_FRONTEND}
EOF
  print_ok ".env.prod gerado"
}

# ══════════════════════════════════════════════════════════════
# 5. Resumo e confirmação
# ══════════════════════════════════════════════════════════════

show_summary() {
  echo ""
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │              Resumo da configuração         │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  Host externo  : ${BOLD}${EXTERNAL_HOST}${NC}"
  echo -e "  Host interno  : ${BOLD}${INTERNAL_HOST}${NC}"
  echo -e "  Sistema base  : ${BOLD}${SYSTEM_BASE_HOST}:${SYSTEM_BASE_PORT}${NC}"
  echo ""
  echo -e "  Backends:"
  echo -e "    Suite API          → porta ${BOLD}${BACKEND_SUITE_API_EXTERNAL_PORT}${NC}"
  echo -e "    People API         → porta ${BOLD}${BACKEND_PEOPLE_API_EXTERNAL_PORT}${NC}"
  echo -e "    AttendanceSystem   → porta ${BOLD}${BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT}${NC}"
  echo -e "    Account API        → porta ${BOLD}${BACKEND_ACCOUNT_API_EXTERNAL_PORT}${NC}"
  echo ""
  echo -e "  Frontends:"
  echo -e "    Suite              → porta ${BOLD}${FRONTEND_SUITE_APP_EXTERNAL_PORT}${NC}"
  echo -e "    People             → porta ${BOLD}${FRONTEND_PEOPLE_APP_EXTERNAL_PORT}${NC}"
  echo -e "    AttendanceSystem   → porta ${BOLD}${FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT}${NC}"
  echo -e "    Account            → porta ${BOLD}${FRONTEND_ACCOUNT_APP_EXTERNAL_PORT}${NC}"
  echo ""
}

# ══════════════════════════════════════════════════════════════
# 6. Subir o ambiente
# ══════════════════════════════════════════════════════════════

start_environment() {
  print_step "Subindo o ambiente..."

  cd "$INSTALL_DIR"
  make up
  cd ..

  echo ""
  echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════════════╗"
  echo -e "  ║     ✅  Instalação concluída com sucesso!    ║"
  echo -e "  ╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Acesse o sistema em:"
  echo -e "  ${CYAN}${BOLD}  ${EXTERNAL_HOST}:${FRONTEND_SUITE_APP_EXTERNAL_PORT}${NC}"
  echo ""
  echo -e "  Comandos úteis (dentro da pasta ${BOLD}${INSTALL_DIR}${NC}):"
  echo -e "    ${BOLD}make up${NC}    → sobe todo o ambiente"
  echo -e "    ${BOLD}make app${NC}   → sobe apenas a aplicação"
  echo -e "    ${BOLD}make infra${NC} → sobe apenas a infra (MongoDB)"
  echo -e "    ${BOLD}make nuke${NC}  → limpa tudo (cuidado!)"
  echo ""
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

main() {
  print_banner
  validate_env
  check_deps
  clone_repo
  collect_config
  show_summary

  if ! confirm "As configurações estão corretas? Deseja prosseguir com a instalação?"; then
    echo ""
    print_warn "Instalação cancelada. Execute o script novamente para reconfigurar."
    exit 0
  fi

  generate_envs

  if confirm "Deseja subir o ambiente agora?"; then
    start_environment
  else
    echo ""
    print_ok "Arquivos gerados. Para subir depois, execute:"
    echo -e "    ${BOLD}cd ${INSTALL_DIR} && make up${NC}"
    echo ""
  fi
}

main "$@"