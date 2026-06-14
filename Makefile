TF_DIR := terraform
TF := terraform -chdir=$(TF_DIR)

.PHONY: init validate fmt plan apply apply-retry destroy output output-kubeconfig clean help

help: ## Показать список команд
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

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
