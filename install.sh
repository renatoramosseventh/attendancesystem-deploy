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
DIM='\033[2m'
NC='\033[0m'

# ─── Repositório Git ──────────────────────────────────────────
GITHUB_USER="renatoramosseventh"
REPO_NAME="attendancesystem-deploy"
INSTALL_DIR="attendancesystem"
BRANCH="${BRANCH:-main}"
ENV_FILE=""

# ══════════════════════════════════════════════════════════════
# Utilitários
# ══════════════════════════════════════════════════════════════

print_banner() {
  clear
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

print_section() {
  echo -e "\n${CYAN}${BOLD}  ── $1 ──${NC}"
}

print_ok()    { echo -e "  ${GREEN}✔ $1${NC}"; }
print_warn()  { echo -e "  ${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "  ${RED}✖ $1${NC}"; }

ensure_http() {
  local val="$1"
  if [[ "$val" != http://* && "$val" != https://* ]]; then
    echo "http://$val"
  else
    echo "$val"
  fi
}

ask() {
  # ask <VARNAME> <prompt> [default]
  local varname="$1"
  local prompt="$2"
  local default="$3"
  local value=""

  if [ -n "$default" ]; then
    echo -ne "  ${BOLD}${prompt}${NC} ${DIM}[${default}]${NC}: "
  else
    echo -ne "  ${BOLD}${prompt}${NC}: "
  fi

  read -r value
  value="${value:-$default}"

  while [ -z "$value" ]; do
    echo -ne "  ${RED}Obrigatório.${NC} ${BOLD}${prompt}${NC}: "
    read -r value
  done

  eval "$varname=\"$value\""
}

confirm() {
  echo -ne "  ${BOLD}$1${NC} ${CYAN}[s/N]${NC}: "
  read -r resp
  [[ "$resp" =~ ^[sS]$ ]]
}

press_enter() {
  echo -ne "\n  ${DIM}Pressione ENTER para continuar...${NC}"
  read -r
}

# ══════════════════════════════════════════════════════════════
# Validar variáveis obrigatórias (TOKEN, DOCKER_USER, DOCKER_PASS)
# ══════════════════════════════════════════════════════════════

validate_env() {
  local errors=0

  [ -z "$TOKEN" ]       && print_error "TOKEN não informado (token GitHub)"       && errors=$((errors+1))
  [ -z "$DOCKER_USER" ] && print_error "DOCKER_USER não informado (Docker Hub)"   && errors=$((errors+1))
  [ -z "$DOCKER_PASS" ] && print_error "DOCKER_PASS não informado (Docker Hub)"   && errors=$((errors+1))

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
# Verificar dependências
# ══════════════════════════════════════════════════════════════

check_deps() {
  print_step "Verificando dependências..."
  local missing=()

  for cmd in docker git make curl; do
    if command -v "$cmd" &>/dev/null; then
      print_ok "$cmd encontrado"
    else
      print_error "$cmd não encontrado"
      missing+=("$cmd")
    fi
  done

  if docker compose version &>/dev/null 2>&1; then
    print_ok "docker compose (plugin) encontrado"
  elif command -v docker-compose &>/dev/null; then
    print_warn "docker-compose v1 encontrado — recomendamos atualizar para v2"
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
# Clonar / atualizar repositório
# ══════════════════════════════════════════════════════════════

clone_repo() {
  print_step "Baixando arquivos do projeto..."

  if [ -d "$INSTALL_DIR" ]; then
    print_warn "A pasta '${INSTALL_DIR}' já existe."
    if confirm "Deseja atualizar os arquivos? (git pull)"; then
      cd "$INSTALL_DIR" && git pull && cd ..
      print_ok "Arquivos atualizados"
    else
      print_warn "Usando arquivos existentes sem atualizar."
    fi
  else
    git clone --branch "$BRANCH" "$GIT_REPO" "$INSTALL_DIR"
    print_ok "Arquivos baixados em: $(pwd)/${INSTALL_DIR}"
  fi

  ENV_FILE="$INSTALL_DIR/.env.prod"
}

# ══════════════════════════════════════════════════════════════
# Carregar .env.prod existente (modo reedição)
# ══════════════════════════════════════════════════════════════

load_existing_env() {
  if [ ! -f "$ENV_FILE" ]; then
    return
  fi

  print_warn "Configuração anterior encontrada em ${ENV_FILE}"

  if confirm "Deseja apenas subir o ambiente sem reconfigurar?"; then
    cd "$INSTALL_DIR" && make install && cd ..
    echo ""
    echo -e "${GREEN}${BOLD}  ✅  Ambiente iniciado com sucesso!${NC}"
    echo ""
    exit 0
  fi

  echo ""
  print_ok "Carregando valores anteriores como padrão..."

  # Lê variáveis do .env.prod ignorando comentários e linhas vazias
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key="${key// /}"
    value="${value// /}"
    eval "$key=\"$value\""
  done < <(grep -v '^#' "$ENV_FILE" | grep -v '^$')

  # Reconstrói SYSTEM_BASE_HOST e PORT a partir de SYSTEM_BASE_CONN se necessário
  if [ -n "$SYSTEM_BASE_CONN" ] && [ -z "$SYSTEM_BASE_HOST" ]; then
    SYSTEM_BASE_HOST="${SYSTEM_BASE_CONN%:*}"
    SYSTEM_BASE_PORT="${SYSTEM_BASE_CONN##*:}"
  fi
}

# ══════════════════════════════════════════════════════════════
# Seções de coleta de configuração
# ══════════════════════════════════════════════════════════════

collect_hosts() {
  print_section "1. Hosts"
  ask INTERNAL_HOST "IP interno desta máquina (rede local)"    "${INTERNAL_HOST:-192.168.10.2}"
  local _ext_default="${EXTERNAL_HOST:-$INTERNAL_HOST}"
  ask EXTERNAL_HOST "IP externo desta máquina (acesso remoto)" "$_ext_default"
  INTERNAL_HOST=$(ensure_http "$INTERNAL_HOST")
  EXTERNAL_HOST=$(ensure_http "$EXTERNAL_HOST")
}

collect_system_base() {
  print_section "2. Sistema Base (legado integrado)"
  ask SYSTEM_BASE_HOST "IP/hostname do sistema base"    "${SYSTEM_BASE_HOST:-192.168.10.1}"
  ask SYSTEM_BASE_PORT "Porta do sistema base"          "${SYSTEM_BASE_PORT:-8080}"
  SYSTEM_BASE_HOST=$(ensure_http "$SYSTEM_BASE_HOST")
}

collect_internal_ports() {
  print_section "3. Portas Internas (rede local)"
  ask BACKEND_SUITE_API_INTERNAL_PORT             "Backend Suite API"             "${BACKEND_SUITE_API_INTERNAL_PORT:-10101}"
  ask BACKEND_PEOPLE_API_INTERNAL_PORT            "Backend People API"            "${BACKEND_PEOPLE_API_INTERNAL_PORT:-10100}"
  ask BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT  "Backend AttendanceSystem API"  "${BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT:-10102}"
  ask BACKEND_ACCOUNT_API_INTERNAL_PORT           "Backend Account API"           "${BACKEND_ACCOUNT_API_INTERNAL_PORT:-10103}"
  ask FRONTEND_SUITE_APP_INTERNAL_PORT            "Frontend Suite"                "${FRONTEND_SUITE_APP_INTERNAL_PORT:-4200}"
  ask FRONTEND_PEOPLE_APP_INTERNAL_PORT           "Frontend People"               "${FRONTEND_PEOPLE_APP_INTERNAL_PORT:-4201}"
  ask FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT "Frontend AttendanceSystem"     "${FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT:-4202}"
  ask FRONTEND_ACCOUNT_APP_INTERNAL_PORT          "Frontend Account"              "${FRONTEND_ACCOUNT_APP_INTERNAL_PORT:-4203}"
}

collect_external_ports() {
  print_section "4. Portas Externas (NAT/acesso remoto)"
  echo -e "  ${DIM}Pressione ENTER para usar a mesma porta interna.${NC}\n"

  ask BACKEND_SUITE_API_EXTERNAL_PORT             "Backend Suite API"             "${BACKEND_SUITE_API_EXTERNAL_PORT:-$BACKEND_SUITE_API_INTERNAL_PORT}"
  ask BACKEND_PEOPLE_API_EXTERNAL_PORT            "Backend People API"            "${BACKEND_PEOPLE_API_EXTERNAL_PORT:-$BACKEND_PEOPLE_API_INTERNAL_PORT}"
  ask BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT  "Backend AttendanceSystem API"  "${BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT:-$BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT}"
  ask BACKEND_ACCOUNT_API_EXTERNAL_PORT           "Backend Account API"           "${BACKEND_ACCOUNT_API_EXTERNAL_PORT:-$BACKEND_ACCOUNT_API_INTERNAL_PORT}"
  ask FRONTEND_SUITE_APP_EXTERNAL_PORT            "Frontend Suite"                "${FRONTEND_SUITE_APP_EXTERNAL_PORT:-$FRONTEND_SUITE_APP_INTERNAL_PORT}"
  ask FRONTEND_PEOPLE_APP_EXTERNAL_PORT           "Frontend People"               "${FRONTEND_PEOPLE_APP_EXTERNAL_PORT:-$FRONTEND_PEOPLE_APP_INTERNAL_PORT}"
  ask FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT "Frontend AttendanceSystem"     "${FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT:-$FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT}"
  ask FRONTEND_ACCOUNT_APP_EXTERNAL_PORT          "Frontend Account"              "${FRONTEND_ACCOUNT_APP_EXTERNAL_PORT:-$FRONTEND_ACCOUNT_APP_INTERNAL_PORT}"
}

collect_database() {
  print_section "5. Banco de Dados"
  ask MONGO_PORT "MongoDB (porta interna)" "${MONGO_PORT:-27017}"
}

# ══════════════════════════════════════════════════════════════
# Wizard principal — coleta com navegação
# ══════════════════════════════════════════════════════════════

collect_config() {
  print_step "Configuração do ambiente"
  echo -e "  ${DIM}Pressione ENTER para aceitar o valor padrão mostrado entre colchetes.${NC}"

  collect_hosts
  collect_system_base

  # Portas externas iguais às internas?
  echo ""
  if confirm "As portas externas são DIFERENTES das internas? (NAT/redirecionamento)"; then
    collect_internal_ports
    collect_external_ports
  else
    collect_internal_ports
    # Copia internas → externas automaticamente
    BACKEND_SUITE_API_EXTERNAL_PORT="$BACKEND_SUITE_API_INTERNAL_PORT"
    BACKEND_PEOPLE_API_EXTERNAL_PORT="$BACKEND_PEOPLE_API_INTERNAL_PORT"
    BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT="$BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT"
    BACKEND_ACCOUNT_API_EXTERNAL_PORT="$BACKEND_ACCOUNT_API_INTERNAL_PORT"
    FRONTEND_SUITE_APP_EXTERNAL_PORT="$FRONTEND_SUITE_APP_INTERNAL_PORT"
    FRONTEND_PEOPLE_APP_EXTERNAL_PORT="$FRONTEND_PEOPLE_APP_INTERNAL_PORT"
    FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT="$FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT"
    FRONTEND_ACCOUNT_APP_EXTERNAL_PORT="$FRONTEND_ACCOUNT_APP_INTERNAL_PORT"
    print_ok "Portas externas definidas iguais às internas."
  fi

  collect_database
}

# ══════════════════════════════════════════════════════════════
# Resumo com menu de edição
# ══════════════════════════════════════════════════════════════

show_summary() {
  while true; do
    echo ""
    echo -e "${CYAN}${BOLD}  ┌──────────────────────────────────────────────────────────────┐"
    echo -e "  │                    Resumo da configuração                    │"
    echo -e "  └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${BOLD}[1] Hosts${NC}"
    echo -e "      Interno : ${BOLD}${INTERNAL_HOST}${NC}"
    echo -e "      Externo : ${BOLD}${EXTERNAL_HOST}${NC}"
    echo ""
    echo -e "  ${BOLD}[2] Sistema Base${NC}"
    echo -e "      Host    : ${BOLD}${SYSTEM_BASE_HOST}${NC}"
    echo -e "      Porta   : ${BOLD}${SYSTEM_BASE_PORT}${NC}"
    echo ""
    echo -e "  ${BOLD}[3] Portas Internas${NC}"
    echo -e "      Backend  Suite/People/Attendance/Account : ${BOLD}${BACKEND_SUITE_API_INTERNAL_PORT}${NC} / ${BOLD}${BACKEND_PEOPLE_API_INTERNAL_PORT}${NC} / ${BOLD}${BACKEND_ATTENDANCESYSTEM_API_INTERNAL_PORT}${NC} / ${BOLD}${BACKEND_ACCOUNT_API_INTERNAL_PORT}${NC}"
    echo -e "      Frontend Suite/People/Attendance/Account : ${BOLD}${FRONTEND_SUITE_APP_INTERNAL_PORT}${NC} / ${BOLD}${FRONTEND_PEOPLE_APP_INTERNAL_PORT}${NC} / ${BOLD}${FRONTEND_ATTENDANCESYSTEM_APP_INTERNAL_PORT}${NC} / ${BOLD}${FRONTEND_ACCOUNT_APP_INTERNAL_PORT}${NC}"
    echo ""
    echo -e "  ${BOLD}[4] Portas Externas${NC}"
    echo -e "      Backend  Suite/People/Attendance/Account : ${BOLD}${BACKEND_SUITE_API_EXTERNAL_PORT}${NC} / ${BOLD}${BACKEND_PEOPLE_API_EXTERNAL_PORT}${NC} / ${BOLD}${BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT}${NC} / ${BOLD}${BACKEND_ACCOUNT_API_EXTERNAL_PORT}${NC}"
    echo -e "      Frontend Suite/People/Attendance/Account : ${BOLD}${FRONTEND_SUITE_APP_EXTERNAL_PORT}${NC} / ${BOLD}${FRONTEND_PEOPLE_APP_EXTERNAL_PORT}${NC} / ${BOLD}${FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT}${NC} / ${BOLD}${FRONTEND_ACCOUNT_APP_EXTERNAL_PORT}${NC}"
    echo ""
    echo -e "  ${BOLD}[5] Banco de Dados${NC}"
    echo -e "      MongoDB : ${BOLD}${MONGO_PORT}${NC}"
    echo ""
    echo -e "  ──────────────────────────────────────────────────────────────"
    echo -e "  ${GREEN}${BOLD}[C]${NC} Confirmar e continuar   ${RED}${BOLD}[X]${NC} Cancelar instalação"
    echo -e "  ──────────────────────────────────────────────────────────────"
    echo ""
    echo -ne "  ${BOLD}Digite o número da seção para editar, C para confirmar ou X para cancelar${NC}: "
    read -r choice

    case "${choice^^}" in
      1) collect_hosts ;;
      2) collect_system_base ;;
      3) collect_internal_ports ;;
      4) collect_external_ports ;;
      5) collect_database ;;
      C) break ;;
      X)
        echo ""
        print_warn "Instalação cancelada."
        exit 0
        ;;
      *)
        print_warn "Opção inválida. Digite 1-5, C ou X."
        ;;
    esac
  done
}

# ══════════════════════════════════════════════════════════════
# Gerar arquivos .env
# ══════════════════════════════════════════════════════════════

generate_envs() {
  print_step "Gerando arquivos de configuração..."

  local BASE_DIR="$INSTALL_DIR"

  cat > "$BASE_DIR/.env.registry" <<EOF
DOCKER_USERNAME="${DOCKER_USER}"
DOCKER_PASSWORD="${DOCKER_PASS}"
EOF
  print_ok ".env.registry gerado"

  local SYSTEM_BASE_CONN="${SYSTEM_BASE_HOST}:${SYSTEM_BASE_PORT}"
  local KEEPALIVE_BACKEND="${EXTERNAL_HOST}:${BACKEND_ATTENDANCESYSTEM_API_EXTERNAL_PORT}"
  local KEEPALIVE_FRONTEND="${EXTERNAL_HOST}:${FRONTEND_ATTENDANCESYSTEM_APP_EXTERNAL_PORT}"

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
# Subir ambiente
# ══════════════════════════════════════════════════════════════

start_environment() {
  print_step "Subindo o ambiente..."
  cd "$INSTALL_DIR"
  make install
  cd ..

  echo ""
  echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════════════╗"
  echo -e "  ║     ✅  Instalação concluída com sucesso!    ║"
  echo -e "  ╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Acesse o sistema em:"
  echo -e "  ${CYAN}${BOLD}  ${SYSTEM_BASE_CONN}${NC}"
  echo -e "  Menu do usuário: Monitoramento (beta)"
  echo ""
  echo -e "  Comandos úteis (dentro da pasta ${BOLD}${INSTALL_DIR}${NC}):"
  echo -e "    ${BOLD}make install${NC} → sobe o projeto"
  echo -e "    ${BOLD}make update${NC}  → atualiza o projeto"
  echo -e "    ${BOLD}make app${NC}   → sobe apenas a aplicação"
  echo -e "    ${BOLD}make infra${NC} → sobe apenas a infra (MongoDB)"
  echo -e "    ${BOLD}make nuke-project${NC}  → limpa o projeto"
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
  load_existing_env   # detecta .env.prod existente
  collect_config      # wizard com navegação
  show_summary        # resumo com menu de edição

  generate_envs

  if confirm "Deseja subir o ambiente agora?"; then
    start_environment
  else
    echo ""
    print_ok "Arquivos gerados. Para subir depois, execute:"
    echo -e "    ${BOLD}cd ${INSTALL_DIR} && make install${NC}"
    echo ""
  fi
}

main "$@"