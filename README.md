# DevOps Engineer from Scratch — инфраструктура в Yandex Cloud

[![Hexlet Check](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml)

**Приложение:** [https://k8s.devops-campus.ru/](https://k8s.devops-campus.ru/)

Terraform разворачивает инфраструктуру в Yandex Cloud и готовит секреты в Lockbox. Приложение **bulletin-board** деплоится в Kubernetes через Helm-чарт с [External Secrets Operator](https://external-secrets.io/) (ESO).

## Что разворачивается

| Компонент | Описание |
|-----------|----------|
| VPC | Сеть `k8s-network`, подсеть `10.2.0.0/16`, NAT Gateway |
| Security Group | Одна SG `k8s-nodegroup-traffic` (master, узлы, NodePort, SSH, PostgreSQL) |
| IAM | Сервисные аккаунты, static key для S3, роли для K8s и Lockbox |
| Object Storage | Бакет `hexlet-bucket` (Terraform state и файлы приложения) |
| Lockbox | Секрет `app-secrets` с параметрами DB/S3 и Docker OAuth |
| Kubernetes | Managed K8s `k8s-cluster`, node group **2 worker-ноды** (`k8s-cluster.tf`) |
| PostgreSQL | Managed PostgreSQL 16 (`postgresql.tf`), JDBC через pooler :6432 |
| Cloud Logging | Лог-группа `k8s-hexlet-logs`, Fluent Bit (`logging.tf`) |

Состояние Terraform хранится в Object Storage (S3 backend), **не в репозитории**.

## Требования

| Инструмент | Версия | Назначение |
|------------|--------|------------|
| [Terraform](https://www.terraform.io/downloads) | >= 1.5 | Управление инфраструктурой |
| [YC CLI](https://yandex.cloud/ru/docs/cli/quickstart) | latest | Аутентификация в Yandex Cloud |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 | Работа с Kubernetes |
| [Helm](https://helm.sh/) | >= 3.12 | Деплой приложения |
| [jq](https://jqlang.github.io/jq/) | latest | Генерация `values.secrets.yaml` |
| [AWS CLI](https://aws.amazon.com/cli/) | latest | Проверка доступа к S3 backend (опционально) |
| [make](https://www.gnu.org/software/make/) | любая | Обёртка над командами |

В каталоге Yandex Cloud нужны права на VPC, Object Storage, Lockbox, IAM, Managed Kubernetes и MDB PostgreSQL.

## Быстрый старт

### 1. YC CLI

```bash
brew install yandex-cloud/tap/yc
yc init
yc config set folder-id b1gepvj6lg03dc9505kh   # ваш folder_id
```

> **Важно:** используйте каталог, в котором уже созданы ресурсы. Не указывайте каталог в статусе `PENDING_DELETION`.

### 2. Переменные Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Заполните `terraform.tfvars`:

| Переменная | Описание |
|------------|----------|
| `folder_id` | ID каталога Yandex Cloud |
| `docker_oauth_token` | OAuth-токен для `cr.yandex` (→ Lockbox) |
| `postgresql_password` | Пароль пользователя Managed PostgreSQL (→ Lockbox) |
| `home_ip` / `office_ip` | Ваши IP в формате CIDR `/32` для API K8s и SSH |

Параметры БД для приложения (`SPRING_DATASOURCE_*`) формируются Terraform автоматически из Managed PostgreSQL.

Ключи S3 (`STORAGE_S3_ACCESS_KEY` / `STORAGE_S3_SECRET_KEY`) **не задаются в tfvars** — Terraform создаёт static key и записывает его в Lockbox.

### 3. Credentials для Terraform

```bash
export YC_TOKEN=$(yc iam create-token)

# Ключи для S3 backend (чтение/запись terraform.tfstate в hexlet-bucket).
# После первого apply возьмите из outputs и сохраните в ~/.zshrc:
export AWS_ACCESS_KEY_ID=$(terraform -chdir=terraform output -raw s3_access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform -chdir=terraform output -raw s3_secret_key)
```

### 4. Terraform + Kubernetes + приложение

```bash
make init
make plan
make deploy-all          # apply-retry + helm-install
make output-kubeconfig   # kubeconfig → terraform/config
export KUBECONFIG=terraform/config
make install-cluster-apps  # ESO + Ingress + cert-manager
make install-fluent-bit    # логи pod → Cloud Logging
make rollout-status      # проверка rolling update
make smoke-test            # 10 запросов к https://k8s.devops-campus.ru/
```

## S3 backend и ключи доступа

| Переменные | Назначение |
|------------|------------|
| `YC_TOKEN` | Yandex-провайдер Terraform (VPC, Lockbox, IAM, бакет, K8s, MDB) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 backend — `terraform/terraform.tfstate` в бакете `hexlet-bucket` |

Static key для S3 создаётся Terraform (`iam-bucket-account`) и попадает в outputs и Lockbox.

## Команды Makefile

Все команды выполняются **из корня репозитория**.

### Terraform

```bash
make help              # список всех команд
make init              # terraform init (S3 backend)
make validate          # проверка конфигурации
make fmt               # форматирование .tf файлов
make plan              # план изменений
make apply             # применить конфигурацию
make apply-retry       # apply с обновлением YC_TOKEN
make output            # все outputs
make output-kubeconfig # kubeconfig → terraform/config
make destroy           # удалить инфраструктуру
make clean             # удалить .terraform/
make deploy-all        # apply-retry + helm-install
```

### Kubernetes / Helm

```bash
make secret_file        # authorized-key.json + доступ ESO SA к Lockbox
make secrets-values     # k8s/bulletin-board/values.secrets.yaml
make clean-helm-orphans # удалить ресурсы без меток Helm
make helm-install       # полный деплой
make helm-upgrade       # обновить release
make helm-uninstall     # удалить release
make helm-lint          # lint + template
make helm-history       # история релизов
make helm-rollback      # откат (REVISION=N)
make install-ingress    # NGINX Ingress Controller
make install-cert-manager
make install-tls        # Ingress + cert-manager
make install-cluster-apps
make install-fluent-bit # Fluent Bit → Cloud Logging
make smoke-test         # проверка URL приложения
make rollout-status     # kubectl rollout status
```

### Переопределение values и откат Helm

**Порядок приоритета values** (последний файл побеждает):

1. `k8s/bulletin-board/values.yaml` — базовые параметры (образ, ingress, HPA)
2. `k8s/bulletin-board/values.secrets.yaml` — ключ ESO (`make secrets-values`, не в Git)
3. `-f custom.yaml` или `--set key=value` при вызове helm

```bash
# Переопределить образ для staging:
helm upgrade --install bulletin-board k8s/bulletin-board \
  -f k8s/bulletin-board/values.yaml \
  -f k8s/bulletin-board/values.secrets.yaml \
  -f k8s/bulletin-board/values.staging.yaml \
  -n hexlet-project

# Откат к предыдущей ревизии:
make helm-history
make helm-rollback              # или REVISION=3 make helm-rollback
```

**CI:** [hexlet-check.yml](.github/workflows/hexlet-check.yml) — автотесты Hexlet ([Actions](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml)). Локально: `make fmt validate helm-lint`. Дополнительные workflows: [validate.yml](.github/workflows/validate.yml), [helm-deploy.yml](.github/workflows/helm-deploy.yml) (ручной деплой).

### Docker Registry (cr.yandex)

Образ приложения: `cr.yandex/crpd2isbgl7k3puo75s1/project-devops-deploy:latest`

| Шаг | Команда |
|-----|---------|
| OAuth-токен для pull | Задаётся в `terraform.tfvars` → Lockbox → ESO → `docker-registry-credentials` |
| Локальный login | `yc iam create-token \| docker login cr.yandex --username oauth --password-stdin` |
| Проверка pull | `kubectl get pods -n hexlet-project` — статус не `ImagePullBackOff` |

Node SA имеет роль `container-registry.images.puller`; дополнительно ESO создаёт Secret с OAuth из Lockbox.

## Kubernetes и приложение

### Предварительные условия

- Managed Kubernetes и PostgreSQL созданы через `make apply`
- [External Secrets Operator](https://external-secrets.io/) установлен в кластере
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server) — для HPA
- `kubectl` и `helm` настроены (`make output-kubeconfig`)

### Helm-чарт `k8s/bulletin-board/`

Release: `bulletin-board`, namespace: `hexlet-project`.

| Ресурс | Имя | Назначение |
|--------|-----|------------|
| Deployment | `hexlet-project` | Spring Boot, RollingUpdate, probes |
| Service | `hexlet-project` | ClusterIP :8080 |
| Ingress | `hexlet-project` | Внешний доступ через NGINX |
| HPA | `hexlet-project-hpa` | memory 350Mi avg (1–2 replicas; CPU отключён на MKS) |
| PDB | `hexlet-project-pdb` | minAvailable: 1 |
| SecretStore | `secret-store` | ESO → Yandex Lockbox |
| ExternalSecret | `app-credentials` | DB и S3 из Lockbox |
| ExternalSecret | `docker-registry-secret` | OAuth для `cr.yandex` |
| ConfigMap | `hexlet-project` | Нечувствительная конфигурация |

Probes: **startup**, **readiness** и **liveness** на `/actuator/health:9090`.

Образ: `cr.yandex/crpd2isbgl7k3puo75s1/project-devops-deploy:latest`

### Деплой

```bash
terraform -chdir=terraform output -raw lockbox_secret_id
# → externalSecrets.lockboxSecretId в k8s/bulletin-board/values.yaml

make helm-install
make install-ingress
```

### Zero-downtime rolling update

Стратегия: `RollingUpdate` с `maxSurge: 1`, `maxUnavailable: 0`, `preStop: sleep 10`.

```bash
# Обновить tag образа в values.yaml, затем:
make helm-upgrade
make rollout-status
make smoke-test   # 10× curl https://k8s.devops-campus.ru/
```

### Доступ к приложению

**Production URL:** [https://k8s.devops-campus.ru/](https://k8s.devops-campus.ru/)

TLS: Let's Encrypt через cert-manager (`ingress.tls.enabled`, `certManager.enabled` в `values.yaml`).

**Ingress:**

```bash
make install-tls
kubectl get ingress hexlet-project -n hexlet-project
kubectl get certificate -n hexlet-project
```

**Локально через port-forward:**

```bash
kubectl port-forward -n hexlet-project svc/hexlet-project 8080:8080
# → http://localhost:8080
```

Actuator health: порт **9090** (`/actuator/health`).

## Outputs Terraform

| Output | Описание |
|--------|----------|
| `kubeconfig` | Kubeconfig для кластера (sensitive) |
| `k8s_cluster_id` | ID Kubernetes-кластера |
| `k8s_node_group_id` | ID группы worker-нод |
| `k8s_api_endpoint` | Endpoint Kubernetes API |
| `postgresql_cluster_id` | ID кластера PostgreSQL |
| `postgresql_cluster_fqdn` | FQDN хоста PostgreSQL |
| `postgresql_connection_string` | Строка подключения (sensitive) |
| `s3_bucket` | Имя бакета (`hexlet-bucket`) |
| `s3_access_key` / `s3_secret_key` | Static key для S3 (sensitive) |
| `lockbox_secret_id` | ID секрета Lockbox для ESO |
| `log_group_id` | ID лог-группы Cloud Logging |
| `log_group_name` | Имя лог-группы (`k8s-hexlet-logs`) |
| `iam_token` | IAM-токен (sensitive, краткоживущий) |

## Lockbox — ключи секрета

| Ключ Lockbox | Источник |
|--------------|----------|
| `docker_oauth_token` | `terraform.tfvars` |
| `STORAGE_S3_ENDPOINT` | Terraform |
| `STORAGE_S3_BUCKET` | Terraform (бакет `hexlet-bucket`) |
| `STORAGE_S3_ACCESS_KEY` | Terraform (static key SA) |
| `STORAGE_S3_SECRET_KEY` | Terraform (static key SA) |
| `SPRING_DATASOURCE_URL` | Terraform (Managed PostgreSQL FQDN) |
| `SPRING_DATASOURCE_USERNAME` | Terraform (`postgresql_user`) |
| `SPRING_DATASOURCE_PASSWORD` | `terraform.tfvars` (`postgresql_password`) |

## Ротация секретов (Lockbox → Kubernetes)

1. Обновите значение в Lockbox:
   ```bash
   # Пример: смена пароля БД
   yc lockbox secret add-version --id $(terraform -chdir=terraform output -raw lockbox_secret_id) \
     --payload "[{\"key\":\"SPRING_DATASOURCE_PASSWORD\",\"text_value\":\"new-password\"}]"
   ```
2. ESO синхронизирует Secret автоматически (refresh interval: **1h** в `values.yaml`).
3. Принудительная синхронизация:
   ```bash
   kubectl annotate externalsecret app-credentials -n hexlet-project \
     force-sync=$(date +%s) --overwrite
   ```
4. Rolling restart без простоя:
   ```bash
   kubectl rollout restart deployment/hexlet-project -n hexlet-project
   make rollout-status
   ```

Секреты **не хранятся в Git** — только в Lockbox и Kubernetes Secrets, созданных ESO.

## Мониторинг (Yandex Cloud)

Подробная инструкция: [docs/monitoring.md](docs/monitoring.md). Скриншоты — в [screenshots/](screenshots/).

| Сервис | Что смотреть | Как открыть |
|--------|--------------|-------------|
| [Monitoring](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring) | CPU/RAM нод, pod metrics, алерты | Консоль → Monitoring |
| Managed Kubernetes | Состояние кластера, нод, pod | Консоль → Managed Service for Kubernetes |
| Managed PostgreSQL | CPU, connections, disk | Консоль → Managed Service for PostgreSQL |
| Cloud Logging | Логи pod (Fluent Bit) | `make install-fluent-bit`, фильтр `hexlet-project` |
| kubectl | Логи в реальном времени | `kubectl logs -n hexlet-project -l app.kubernetes.io/name=hexlet-application -f` |

**Отслеживаемые метрики:** CPU/RAM нод и pod, restarts, HPA replicas, HTTP health (`/actuator/health:9090`), PostgreSQL connections.

**Алерты** (9 шт.: доступность, 5xx, latency, restarts, нагрузка): [docs/alerts-setup.md](docs/alerts-setup.md). Проверка: `make check-monitoring-queries`.

**Логи в Cloud Logging:**
```bash
yc logging read --group-id $(terraform -chdir=terraform output -raw log_group_id) \
  --since 1h --filter 'json_payload.kubernetes.namespace_name="hexlet-project"' --limit 10
```

Если лог-группа создана вручную до Terraform:
```bash
make import-log-group
make apply-retry
```

## Структура проекта

```
.
├── Makefile
├── requirements.txt                # чеклист учебного проекта Hexlet
├── docker-compose.yaml
├── screenshots/                    # скриншоты мониторинга и логов (README)
├── docs/
│   └── monitoring.md               # метрики, алерты, Fluent Bit
├── .github/workflows/
│   ├── hexlet-check.yml
│   ├── validate.yml                # terraform fmt/validate, helm lint
│   └── helm-deploy.yml             # опциональный helm deploy (manual)
├── terraform/
│   ├── versions.tf                 # S3 backend (hexlet-bucket)
│   ├── providers.tf
│   ├── network.tf                  # VPC, NAT
│   ├── security-group.tf
│   ├── iam.tf
│   ├── object-storage-bucket.tf
│   ├── lockbox.tf
│   ├── logging.tf                  # Cloud Logging log group
│   ├── k8s-cluster.tf              # Managed K8s, 2 worker-ноды
│   ├── postgresql.tf               # Managed PostgreSQL
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── k8s/
    ├── fluent-bit/systemd.yaml     # values для Fluent Bit Marketplace
    └── bulletin-board/             # Helm-чарт
    ├── values.yaml
    └── templates/
        ├── deployment.yaml         # RollingUpdate, probes
        ├── service.yaml
        ├── ingress.yaml
        ├── hpa.yaml
        ├── poddisruptionbudget.yaml
        ├── configmap.yaml
        ├── secretstore.yaml
        ├── external-secret.yaml
        ├── external-secret-app.yaml
        └── ...
```

## Сеть

- VPC `k8s-network`, подсеть `10.2.0.0/16` в `ru-central1-a`
- NAT Gateway для исходящего трафика
- Одна SG (лимит каталога `vpc.securityGroups.count = 5`)
- API Kubernetes и SSH — с IP из `home_ip` / `office_ip`
- PostgreSQL (порт 6432) — из подсети K8s

## Секреты — не коммитить

- `terraform/terraform.tfvars`
- `terraform/config` (kubeconfig)
- `k8s/authorized-key.json`
- `k8s/fluent-bit-auth.json`
- `k8s/bulletin-board/values.secrets.yaml`
- `.terraform/`, `*.tfstate`

## Типичные проблемы

| Ошибка | Решение |
|--------|---------|
| `SignatureDoesNotMatch` при `terraform init/plan` | Обновите `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` из `terraform output` |
| `PermissionDenied` в каталоге | Проверьте `folder_id` и статус каталога |
| `invalid ownership metadata` при `helm install` | `make clean-helm-orphans` → `make helm-install` |
| ExternalSecret `SecretSyncedError` | Проверьте `lockboxSecretId`, Secret `yc-auth`, роль `lockbox.payloadViewer` |
| `ImagePullBackOff` / 401 | Проверьте `docker_oauth_token` в Lockbox |
| Ingress без ADDRESS | Дождитесь LoadBalancer или выполните `make install-ingress` |
| HPA warnings / CPU `<unknown>` | На Yandex MKS HPA использует только memory; CPU-метрика отключена в values |
| Лог-группа уже существует (`AlreadyExists`) | `make import-log-group` затем `make apply-retry` (или просто `make apply-retry` — в `logging.tf` есть import block) |
