TF_DIR := terraform
K8S_DIR := k8s
TF := terraform -chdir=$(TF_DIR)

YC := $(shell command -v yc 2>/dev/null || echo yc)
KUBECONFIG_FILE := $(abspath $(TF_DIR)/config)
export KUBECONFIG := $(KUBECONFIG_FILE)

# Terraform с актуальным IAM-токеном
TF_WITH_YC = YC_TOKEN=$$($(YC) iam create-token)

HELM_CHART := $(K8S_DIR)/bulletin-board
HELM_RELEASE := bulletin-board
HELM_NAMESPACE := hexlet-project
VALUES := $(HELM_CHART)/values.yaml
SECRETS_VALUES := $(HELM_CHART)/values.secrets.yaml
AUTH_KEY := $(K8S_DIR)/authorized-key.json
FLUENT_BIT_AUTH := $(K8S_DIR)/fluent-bit-auth.json
FLUENT_BIT_CHART := /tmp/fluent-bit-chart
FLUENT_BIT_VERSION := 2.1.7-3
APP_URL := https://k8s.devops-campus.ru/

# Ресурсы чарта, которые могли быть созданы через kubectl apply
ORPHAN_RESOURCES := \
	secret/yc-auth \
	externalsecret/app-credentials \
	externalsecret/docker-registry-secret \
	secretstore/secret-store

.PHONY: init validate fmt plan plan-retry apply apply-retry apply-kube destroy output output-kubeconfig clean help env \
	secret_file secrets-values clean-helm-orphans secret helm-install helm-upgrade helm-uninstall \
	deploy-all install-external-secrets install-cert-manager install-ingress install-tls rollout-status \
	helm-lint helm-history helm-rollback smoke-test install-cluster-apps install-fluent-bit \
	fluent-bit-auth import-log-group check-monitoring-queries open-monitoring-alerts

help: ## Показать список команд
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

env: ## Показать export YC_TOKEN и KUBECONFIG для текущего shell
	@echo "export YC_TOKEN=$$($(YC) iam create-token)"
	@echo "export KUBECONFIG=$(KUBECONFIG_FILE)"

init: ## Инициализация Terraform (провайдеры, S3 backend)
	$(TF) init

validate: ## Проверка синтаксиса конфигурации
	$(TF) validate

fmt: ## Форматирование .tf files
	$(TF) fmt -recursive

plan: ## План изменений инфраструктуры
	$(TF) plan

plan-retry: ## plan с обновлением IAM-токена
	$(TF_WITH_YC) $(TF) plan

apply: ## Применение конфигурации (обновите YC_TOKEN перед длинным apply)
	$(TF) apply

apply-retry: ## apply с обновлением IAM-токена
	$(TF_WITH_YC) $(TF) apply

apply-kube: apply-retry output-kubeconfig ## apply + kubeconfig (KUBECONFIG=terraform/config)
	@echo "KUBECONFIG=$(KUBECONFIG_FILE)"
	@kubectl cluster-info 2>/dev/null || true

destroy: ## Удаление всей инфраструктуры
	$(TF) destroy

output: ## Вывод всех outputs
	$(TF) output

output-kubeconfig: ## Сохранить kubeconfig в terraform/config
	@$(TF) output -json kubeconfig >/dev/null 2>&1 || { \
		echo "Output kubeconfig не найден в state."; \
		echo "Кластер K8s ещё не создан — сначала выполните: make apply-kube"; \
		exit 1; \
	}
	$(TF) output -raw kubeconfig > $(TF_DIR)/config
	@# Подставить актуальный путь к yc (не /usr/local/bin/yc)
	@if [ "$$(uname)" = "Darwin" ]; then \
		sed -i '' "s|command: .*|command: $(YC)|" $(TF_DIR)/config; \
	else \
		sed -i "s|command: .*|command: $(YC)|" $(TF_DIR)/config; \
	fi
	@echo "Kubeconfig сохранён в $(TF_DIR)/config (yc: $(YC))"

clean: ## Удалить локальный кэш провайдеров (.terraform)
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl

secret_file: ## Создать authorized-key.json и выдать ESO доступ к Lockbox
	SA_ID=$$($(YC) iam service-account get eso-service-account --format json | jq -r .id) && \
	LOCKBOX_ID=$$($(TF) output -raw lockbox_secret_id 2>/dev/null || \
		$(YC) lockbox secret list --format json | jq -r '.[] | select(.name=="app-secrets") | .id') && \
	$(YC) lockbox secret add-access-binding \
		--id "$$LOCKBOX_ID" \
		--role lockbox.payloadViewer \
		--service-account-id "$$SA_ID" && \
	$(YC) iam key create \
		--service-account-name eso-service-account \
		--output $(AUTH_KEY)

$(AUTH_KEY):
	$(MAKE) secret_file

secrets-values: $(AUTH_KEY) ## Сгенерировать k8s/bulletin-board/values.secrets.yaml из authorized-key.json
	jq -n --slurpfile key $(AUTH_KEY) \
		'{externalSecrets: {ycAuth: {authorizedKey: $$key[0]}}}' \
		> $(SECRETS_VALUES)
	@echo "Создан $(SECRETS_VALUES)"

clean-helm-orphans: ## Удалить K8s-ресурсы без меток Helm (остатки kubectl apply)
	@ns="$(HELM_NAMESPACE)"; rel="$(HELM_RELEASE)"; \
	for res in $(ORPHAN_RESOURCES); do \
		kind=$${res%%/*}; name=$${res#*/}; \
		current=$$(kubectl get $$kind $$name -n $$ns \
			-o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true); \
		if [ "$$current" != "$$rel" ]; then \
			echo "Deleting orphan $$kind/$$name"; \
			kubectl delete $$kind $$name -n $$ns --ignore-not-found; \
		fi; \
	done

secret: secrets-values clean-helm-orphans ## Helm upgrade --install с секретами Lockbox
	kubectl get namespace $(HELM_NAMESPACE) >/dev/null 2>&1 || kubectl create namespace $(HELM_NAMESPACE)
	helm upgrade --install $(HELM_RELEASE) ./$(HELM_CHART) \
		-f $(VALUES) -f $(SECRETS_VALUES) \
		-n $(HELM_NAMESPACE)

helm-install: secret ## Установить Helm release bulletin-board

helm-upgrade: secret ## Обновить Helm release bulletin-board

helm-uninstall: ## Удалить Helm release bulletin-board
	-helm uninstall $(HELM_RELEASE) -n $(HELM_NAMESPACE)

helm-lint: ## Проверить Helm-чарт (lint + template)
	helm lint $(HELM_CHART) -f $(VALUES)
	helm template $(HELM_RELEASE) $(HELM_CHART) -f $(VALUES) > /dev/null

helm-history: ## История релизов Helm
	helm history $(HELM_RELEASE) -n $(HELM_NAMESPACE)

helm-rollback: ## Откат Helm release (REVISION=N, по умолчанию предыдущая)
	@rev=$${REVISION:-$$(helm history $(HELM_RELEASE) -n $(HELM_NAMESPACE) --max 2 -o json | jq -r '.[0].revision // empty')}; \
	if [ -z "$$rev" ]; then echo "Release не найден"; exit 1; fi; \
	echo "Rollback $(HELM_RELEASE) → revision $$rev"; \
	helm rollback $(HELM_RELEASE) $$rev -n $(HELM_NAMESPACE)

smoke-test: ## Проверка доступности приложения (10 запросов к APP_URL)
	@url="$${APP_URL:-$(APP_URL)}"; \
	echo "Smoke test: $$url"; \
	ok=0; fail=0; \
	for i in $$(seq 1 10); do \
		if curl -sf --max-time 10 "$$url" >/dev/null; then ok=$$((ok+1)); echo "OK $$i"; \
		else fail=$$((fail+1)); echo "FAIL $$i"; fi; \
		sleep 1; \
	done; \
	echo "Result: $$ok ok, $$fail fail"; [ "$$fail" -eq 0 ]

deploy-all: apply-kube helm-install ## Terraform apply + kubeconfig + Helm deploy

install-external-secrets: ## Установить External Secrets Operator
	helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
	helm repo update external-secrets
	helm search repo external-secrets/external-secrets
	helm upgrade --install external-secrets external-secrets/external-secrets \
		-n external-secrets --create-namespace

install-ingress: ## Установить NGINX Ingress Controller в кластер
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
	helm repo update
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		--set controller.service.type=LoadBalancer

install-cert-manager: ## Установить cert-manager (Let's Encrypt)
	helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
	helm repo update jetstack
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--set crds.enabled=true

install-tls: install-ingress install-cert-manager ## Ingress + cert-manager для HTTPS

install-cluster-apps: install-external-secrets install-tls ## ESO + Ingress + cert-manager

fluent-bit-auth: ## Ключ SA resource-manager-account для Fluent Bit → Cloud Logging
	$(YC) iam key create \
		--service-account-name resource-manager-account \
		--output $(FLUENT_BIT_AUTH)
	@echo "Создан $(FLUENT_BIT_AUTH)"

import-log-group: ## Импорт существующей лог-группы в Terraform state
	$(TF) import yandex_logging_group.k8s_logs e23c06dnp7m5sr2vai4e

install-fluent-bit: fluent-bit-auth ## Fluent Bit → Cloud Logging (Helm Marketplace)
	@LOG_GROUP_ID=$$($(TF) output -raw log_group_id 2>/dev/null) || { \
		echo "log_group_id не найден. Выполните: make apply-retry (или make import-log-group)"; exit 1; }; \
	CLUSTER_ID=$$($(TF) output -raw k8s_cluster_id 2>/dev/null) || { \
		echo "k8s_cluster_id не найден. Выполните: make apply-retry"; exit 1; }; \
	echo "loggingGroupId=$$LOG_GROUP_ID loggingFilter=$$CLUSTER_ID"; \
	cat $(FLUENT_BIT_AUTH) | helm registry login cr.yandex --username json_key --password-stdin; \
	rm -rf $(FLUENT_BIT_CHART); \
	helm pull oci://cr.yandex/yc-marketplace/yandex-cloud/fluent-bit/fluent-bit \
		--version $(FLUENT_BIT_VERSION) --untar -d /tmp; \
	helm upgrade --install fluentbit /tmp/fluent-bit \
		-f $(K8S_DIR)/fluent-bit/systemd.yaml \
		-n logging --create-namespace \
		--set loggingGroupId=$$LOG_GROUP_ID \
		--set loggingFilter=$$CLUSTER_ID \
		--set-file auth.json=$(FLUENT_BIT_AUTH)

rollout-status: ## Проверить статус rolling update Deployment
	kubectl rollout status deployment/hexlet-project -n $(HELM_NAMESPACE) --timeout=5m
	kubectl get pods -n $(HELM_NAMESPACE) -o wide

check-monitoring-queries: ## Проверить запросы алертов Monitoring
	@chmod +x scripts/check-monitoring-queries.sh
	@FOLDER_ID=$$($(TF) output -raw folder_id 2>/dev/null || echo b1gepvj6lg03dc9505kh); \
	CLUSTER_ID=$$($(TF) output -raw k8s_cluster_id 2>/dev/null || echo catb3ouu6c06vh9fofit); \
	FOLDER_ID="$$FOLDER_ID" CLUSTER_ID="$$CLUSTER_ID" ./scripts/check-monitoring-queries.sh

open-monitoring-alerts: ## Открыть консоль Monitoring → Алерты
	@echo "https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring/alerts/create"
	@open "https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring/alerts/create" 2>/dev/null || true
