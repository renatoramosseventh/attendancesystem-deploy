ENV ?= prod
COMPOSE_FILE = docker-compose.yml
ENV_FILE = .env.$(ENV)

PROJECT_NAME = attendancesystem-$(ENV)
NETWORK_NAME = attendancesystem-network

include .env.registry

.PHONY: login infra app install update reset-network nuke nuke-project

# ===============================
# 🔐 Docker Hub Login
# ===============================
login:
	@echo "🔐 Login seguro Docker Hub..."
	@echo $(DOCKER_PASSWORD) | docker login -u $(DOCKER_USERNAME) --password-stdin

# ===============================
# 🏗 Subir apenas INFRA
# ===============================
infra: reset-network
	@echo "🚀 Subindo apenas INFRA ($(PROJECT_NAME))..."
	docker compose \
		--project-name $(PROJECT_NAME) \
		--env-file $(ENV_FILE) \
		--profile infra \
		-f $(COMPOSE_FILE) \
		up -d

# ===============================
# 🧹 Reset Network
# ===============================
reset-network:
	@echo "🧹 Removendo rede antiga (se existir)..."
	-docker network rm $(NETWORK_NAME) 2>/dev/null || true

# ===============================
# 🧩 Subir apenas APP
# ===============================
app: login
	@echo "🚀 Subindo apenas APP ($(PROJECT_NAME))..."
	docker compose \
		--project-name $(PROJECT_NAME) \
		--env-file $(ENV_FILE) \
		--profile app \
		-f $(COMPOSE_FILE) \
		up -d

# ===============================
# 🔥 Subir TUDO
# ===============================
install: login
	@echo "🚀 Subindo ambiente completo ($(PROJECT_NAME))..."
	docker compose \
		--project-name $(PROJECT_NAME) \
		--env-file $(ENV_FILE) \
		--profile infra \
		--profile app \
		-f $(COMPOSE_FILE) \
		up -d

# ===============================
# 🔄 Atualizar projeto
# ===============================
update: nuke-project install

# ===============================
# 💣 Limpeza TOTAL
# ===============================
nuke:
	@echo "💣 Iniciando limpeza do ambiente..."

	@echo "🛑 Parando containers..."
	- docker stop $$(docker ps -aq) 2>/dev/null || true

	@echo "🗑️ Removendo containers..."
	- docker rm -f $$(docker ps -aq) 2>/dev/null || true

	@echo "📦 Removendo volumes..."
	- docker volume rm $$(docker volume ls -q) 2>/dev/null || true

	@echo "🖼️ Removendo imagens..."
	- docker rmi -f $$(docker images -aq) 2>/dev/null || true

	@echo "🌐 Limpando redes não utilizadas..."
	- docker network prune -f 2>/dev/null || true

	@echo "🔥 Limpeza GLOBAL concluída."

# ===============================
# 🧹 Limpeza do projeto
# ===============================
nuke-project:
	@echo "🧹 Limpando o projeto $(PROJECT_NAME)..."

	@echo "🛑 Parando e removendo containers do projeto..."
	docker compose \
		--project-name $(PROJECT_NAME) \
		--env-file $(ENV_FILE) \
		--profile infra \
		--profile app \
		-f $(COMPOSE_FILE) \
		down --volumes --remove-orphans

	@echo "🖼️ Removendo imagens do projeto ($(DOCKER_USERNAME))..."
	- docker images --format '{{.Repository}}:{{.Tag}}' | grep '^$(DOCKER_USERNAME)/' | xargs -r docker rmi -f 2>/dev/null || true

	@echo "✅ Projeto $(PROJECT_NAME) limpo (containers, volumes, rede e imagens)."
	@echo "   Imagens de infraestrutura preservadas."