ENV ?= prod
COMPOSE_FILE = docker-compose.yml
ENV_FILE = .env.$(ENV)

PROJECT_NAME = attendancesystem-$(ENV)
NETWORK_NAME = attendancesystem-network

.PHONY: login infra app up reset-network nuke

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
up: login
	@echo "🚀 Subindo ambiente completo ($(PROJECT_NAME))..."
	docker compose \
		--project-name $(PROJECT_NAME) \
		--env-file $(ENV_FILE) \
		--profile infra \
		--profile app \
		-f $(COMPOSE_FILE) \
		up -d

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