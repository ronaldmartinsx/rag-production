.PHONY: dev qdrant docker down logs help

# Sobe tudo o que a aplicacao precisa e inicia a API (com auto-reload).
dev: qdrant
	@echo "==> Subindo FastAPI em http://localhost:8000 (Ctrl+C para parar)"
	uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Garante o Qdrant no ar (depende do Docker estar rodando).
qdrant: docker
	@docker compose up -d
	@echo "==> Aguardando Qdrant ficar pronto..."
	@for i in $$(seq 1 30); do \
		curl -s -m 2 http://localhost:6333/readyz >/dev/null 2>&1 && { echo "==> Qdrant OK (localhost:6333)"; exit 0; }; \
		sleep 1; \
	done; \
	echo "!! Qdrant nao respondeu a tempo"; exit 1

# Garante o daemon do Docker rodando (abre o Docker Desktop no macOS se preciso).
docker:
	@if docker info >/dev/null 2>&1; then \
		echo "==> Docker OK"; \
	else \
		echo "==> Iniciando Docker Desktop..."; \
		open -a Docker; \
		for i in $$(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 2; done; \
		docker info >/dev/null 2>&1 || { echo "!! Docker nao ficou pronto"; exit 1; }; \
		echo "==> Docker OK"; \
	fi

# Para o Qdrant (mantem os dados no volume).
down:
	@docker compose down

# Acompanha os logs do Qdrant.
logs:
	@docker compose logs -f qdrant

help:
	@echo "make dev     - sobe Docker+Qdrant e roda a API (localhost:8000)"
	@echo "make qdrant  - sobe apenas o Qdrant"
	@echo "make down    - para o Qdrant (dados preservados)"
	@echo "make logs    - logs do Qdrant"
