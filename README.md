# DevOps Engineer from Scratch — инфраструктура в Yandex Cloud

[![Actions Status](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions)

Terraform-проект разворачивает базовую инфраструктуру в Yandex Cloud и готовит секреты для приложения в Kubernetes через Lockbox и External Secrets Operator (ESO).

## Что разворачивается

| Компонент | Описание |
|-----------|----------|
| VPC | Сеть `k8s-network`, подсеть `10.2.0.0/16`, NAT Gateway |
| Security Group | Одна SG `k8s-nodegroup-traffic` (master, узлы, NodePort, SSH, PostgreSQL) |
| IAM | Сервисные аккаунты, static key для S3, роли для K8s и Lockbox |
| Object Storage | Бакет `hexlet-bucket` (хранит Terraform state и файлы приложения) |
| Lockbox | Секрет `app-secrets` с параметрами DB/S3 и Docker OAuth |
| Kubernetes | Манифесты в `k8s/`; Managed K8s в Terraform (`k8s-cluster.tf`) — **закомментирован** |
| PostgreSQL | Managed PostgreSQL (`postgresql.tf`) — **закомментирован** |

Состояние Terraform хранится в Object Storage (S3 backend), **не в репозитории**.

## Требования

| Инструмент | Версия | Назначение |
|------------|--------|------------|
| [Terraform](https://www.terraform.io/downloads) | >= 1.5 | Управление инфраструктурой |
| [YC CLI](https://yandex.cloud/ru/docs/cli/quickstart) | latest | Аутентификация в Yandex Cloud |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 | Работа с Kubernetes |
| [AWS CLI](https://aws.amazon.com/cli/) | latest | Проверка доступа к S3 backend (опционально) |
| [make](https://www.gnu.org/software/make/) | любая | Обёртка над командами |

В каталоге Yandex Cloud нужны права на VPC, Object Storage, Lockbox, IAM. Для Managed K8s и MDB — соответствующие роли (при раскомментировании ресурсов).

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
| `postgresql_password` | Пароль PostgreSQL (если используете MDB) |
| `spring_datasource_url` | JDBC URL для приложения (→ Lockbox) |
| `spring_datasource_username` | Пользователь БД (→ Lockbox) |
| `spring_datasource_password` | Пароль БД (→ Lockbox) |
| `home_ip` / `office_ip` | Ваши IP в формате CIDR `/32` для API K8s и SSH |

Ключи S3 (`STORAGE_S3_ACCESS_KEY` / `STORAGE_S3_SECRET_KEY`) **не задаются в tfvars** — Terraform создаёт static key и записывает его в Lockbox автоматически.

### 3. Credentials для Terraform

```bash
export YC_TOKEN=$(yc iam create-token)

# Ключи для S3 backend (чтение/запись terraform.tfstate в hexlet-bucket).
# После первого apply возьмите из outputs и сохраните в ~/.zshrc:
export AWS_ACCESS_KEY_ID=$(terraform -chdir=terraform output -raw s3_access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform -chdir=terraform output -raw s3_secret_key)
```

Проверка доступа к state:

```bash
aws s3 ls s3://hexlet-bucket/terraform/ \
  --endpoint-url=https://storage.yandexcloud.net \
  --region ru-central1-a
```

### 4. Terraform

```bash
make init
make validate
make plan
make apply          # или make apply-retry — обновляет YC_TOKEN перед apply
make output
```

## S3 backend и ключи доступа

Два независимых набора credentials:

| Переменные | Назначение |
|------------|------------|
| `YC_TOKEN` | Yandex-провайдер Terraform (VPC, Lockbox, IAM, бакет) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3 backend — файл `terraform/terraform.tfstate` в бакете `hexlet-bucket` |

Static key для S3 создаётся Terraform (`iam-bucket-account`) и попадает в:

- outputs `s3_access_key` / `s3_secret_key`
- Lockbox (`STORAGE_S3_ACCESS_KEY`, `STORAGE_S3_SECRET_KEY`)

**Вводить S3-ключи в tfvars не нужно.** Обновлять `AWS_*` в shell нужно только если static key был пересоздан.

## Команды Makefile

```bash
make help              # список команд
make init              # terraform init (подключение S3 backend)
make validate          # проверка конфигурации
make fmt               # форматирование .tf файлов
make plan              # план изменений
make apply             # применить конфигурацию
make apply-retry       # apply с обновлением YC_TOKEN
make output            # все outputs
make output-kubeconfig # kubeconfig → terraform/config (если K8s создан)
make destroy           # удалить инфраструктуру
make clean             # удалить .terraform/
```

## Kubernetes и приложение

### Предварительные условия

- Managed Kubernetes-кластер (создан через Terraform или вручную)
- [External Secrets Operator](https://external-secrets.io/) установлен в кластере
- `kubectl` настроен на нужный кластер

### Деплой

```bash
# 1. Namespace и базовые ресурсы
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/serviceaccount.yml

# 2. SecretStore для Lockbox (нужен authorized-key.json)
cd k8s
make secret_file   # создаёт authorized-key.json и выдаёт доступ ESO к Lockbox
make secret        # создаёт Secret yc-auth в namespace hexlet-project
kubectl apply -f secretstore.yml

# 3. ExternalSecret — подставьте актуальный lockbox_secret_id из terraform output
terraform -chdir=../terraform output -raw lockbox_secret_id
# обновите key: в external-secret.yml и external-secret-app.yml
kubectl apply -f external-secret.yml
kubectl apply -f external-secret-app.yml

# 4. Приложение
kubectl apply -f deployment.yml
kubectl apply -f service.yml
```

### Проверка

```bash
kubectl get pods -n hexlet-project
kubectl get externalsecret -n hexlet-project
kubectl describe svc hexlet-project -n hexlet-project
```

### Доступ к приложению

Сервис `hexlet-project` — тип **ClusterIP**, порт **8080**.

```bash
# Локальный доступ через port-forward
kubectl port-forward -n hexlet-project svc/hexlet-project 8080:8080
# → http://localhost:8080
```

Для доступа снаружи кластера измените `type` сервиса на `NodePort` (порты 30000–32767 открыты в SG).

## Outputs Terraform

| Output | Описание |
|--------|----------|
| `s3_bucket` | Имя бакета (`hexlet-bucket`) |
| `s3_access_key` / `s3_secret_key` | Static key для S3 (sensitive) |
| `s3_endpoint` | `https://storage.yandexcloud.net` |
| `lockbox_secret_id` | ID секрета Lockbox для ESO |
| `iam_token` | IAM-токен (sensitive, краткоживущий) |

Outputs K8s и PostgreSQL (`kubeconfig`, `k8s_cluster_id`, …) доступны после раскомментирования соответствующих ресурсов в `k8s-cluster.tf` и `postgresql.tf`.

```bash
terraform -chdir=terraform output lockbox_secret_id
terraform -chdir=terraform output -raw s3_access_key
```

## Lockbox — ключи секрета

| Ключ Lockbox | Источник |
|--------------|----------|
| `docker_oauth_token` | `terraform.tfvars` |
| `STORAGE_S3_ENDPOINT` | Terraform (`local.s3_endpoint`) |
| `STORAGE_S3_BUCKET` | Terraform (бакет `hexlet-bucket`) |
| `STORAGE_S3_ACCESS_KEY` | Terraform (static key SA) |
| `STORAGE_S3_SECRET_KEY` | Terraform (static key SA) |
| `SPRING_DATASOURCE_URL` | `terraform.tfvars` |
| `SPRING_DATASOURCE_USERNAME` | `terraform.tfvars` |
| `SPRING_DATASOURCE_PASSWORD` | `terraform.tfvars` |

## Структура проекта

```
.
├── Makefile                 # Команды Terraform
├── terraform/
│   ├── versions.tf          # Terraform, S3 backend (hexlet-bucket)
│   ├── providers.tf         # Провайдер yandex
│   ├── variables.tf         # Входные переменные
│   ├── network.tf           # VPC, подсеть, NAT, route table
│   ├── security-group.tf    # Security group для K8s/PostgreSQL
│   ├── iam.tf               # Сервисные аккаунты, static key, роли
│   ├── object-storage-bucket.tf
│   ├── lockbox.tf           # Lockbox-секрет приложения
│   ├── k8s-cluster.tf       # Managed K8s (закомментирован)
│   ├── postgresql.tf        # Managed PostgreSQL (закомментирован)
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── k8s/
    ├── namespace.yml
    ├── deployment.yml
    ├── service.yml          # ClusterIP :8080
    ├── configmap.yml
    ├── serviceaccount.yml
    ├── secretstore.yml      # SecretStore → Yandex Lockbox
    ├── external-secret.yml  # Docker registry credentials
    ├── external-secret-app.yml
    └── Makefile             # secret_file / secret для ESO
```

## Сеть

- VPC `k8s-network`, подсеть `10.2.0.0/16` в `ru-central1-a`
- NAT Gateway для исходящего трафика
- Одна SG вместо нескольких (лимит каталога `vpc.securityGroups.count = 5`)
- API Kubernetes и SSH — с IP из `home_ip` / `office_ip`
- PostgreSQL (порт 6432) — из подсети K8s и домашних IP

## Секреты — не коммитить

- `terraform/terraform.tfvars` — пароли, OAuth-токены
- `terraform/config` — kubeconfig
- `k8s/authorized-key.json` — ключ ESO для Lockbox
- `.terraform/`, `*.tfstate` — state и провайдеры

Файл `.gitignore` настроен для Terraform; `authorized-key.json` храните локально.

## Типичные проблемы

| Ошибка | Решение |
|--------|---------|
| `SignatureDoesNotMatch` при `terraform init/plan` | Обновите `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` из `terraform output` |
| `403 Forbidden` при чтении бакета | Убедитесь, что `folder_id` верный; бакет не должен использовать устаревшие ключи из state |
| `PermissionDenied` в каталоге | Проверьте `folder_id` и статус каталога (`yc resource-manager folder list`) |
| `Quota limit vpc.securityGroups.count exceeded` | В проекте одна SG; удалите неиспользуемые SG в каталоге |
| ExternalSecret не синхронизируется | Проверьте `lockbox_secret_id` в YAML, Secret `yc-auth`, роль `lockbox.payloadViewer` для ESO SA |
| `Endpoints: <none>` у Service | Pod не готов или labels не совпадают с selector сервиса |
