TF_DIR := terraform
K8S_DIR := k8s
TF := terraform -chdir=$(TF_DIR)

HELM_CHART := $(K8S_DIR)/bulletin-board
HELM_RELEASE := bulletin-board
HELM_NAMESPACE := hexlet-project
VALUES := $(HELM_CHART)/values.yaml
SECRETS_VALUES := $(HELM_CHART)/values.secrets.yaml
AUTH_KEY := $(K8S_DIR)/authorized-key.json

# Ресурсы чарта, которые могли быть созданы через kubectl apply
ORPHAN_RESOURCES := \
	secret/yc-auth \
	externalsecret/app-credentials \
	externalsecret/docker-registry-secret \
	secretstore/secret-store

.PHONY: init validate fmt plan apply apply-retry destroy output output-kubeconfig clean help \
	secret_file secrets-values clean-helm-orphans secret helm-install helm-upgrade helm-uninstall

help: ## Показать список команд
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

init: ## Инициализация Terraform (провайдеры, S3 backend)
	$(TF) init

validate: ## Проверка синтаксиса конфигурации
	$(TF) validate

fmt: ## Форматирование .tf файлов
	$(TF) fmt -recursive

plan: ## План изменений инфраструктуры
	$(TF) plan

apply: ## Применение конфигурации (обновите YC_TOKEN перед длинным apply)
	$(TF) apply

apply-retry: ## apply с обновлением IAM-токена (рекомендуется после ошибки Permission denied)
	YC_TOKEN=$$(yc iam create-token) $(TF) apply

destroy: ## Удаление всей инфраструктуры
	$(TF) destroy

output: ## Вывод всех outputs
	$(TF) output

output-kubeconfig: ## Сохранить kubeconfig в terraform/config
	@$(TF) output -json kubeconfig >/dev/null 2>&1 || { \
		echo "Output kubeconfig не найден в state."; \
		echo "Кластер K8s ещё не создан — сначала выполните: make apply-retry"; \
		exit 1; \
	}
	$(TF) output -raw kubeconfig > $(TF_DIR)/config
	@echo "Kubeconfig сохранён в $(TF_DIR)/config"

clean: ## Удалить локальный кэш провайдеров (.terraform)
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl

secret_file: ## Создать authorized-key.json и выдать ESO доступ к Lockbox
	SA_ID=$$(yc iam service-account get eso-service-account --format json | jq -r .id) && \
	LOCKBOX_ID=$$($(TF) output -raw lockbox_secret_id 2>/dev/null || \
		yc lockbox secret list --format json | jq -r '.[] | select(.name=="app-secrets") | .id') && \
	yc lockbox secret add-access-binding \
		--id "$$LOCKBOX_ID" \
		--role lockbox.payloadViewer \
		--service-account-id "$$SA_ID" && \
	yc iam key create \
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
