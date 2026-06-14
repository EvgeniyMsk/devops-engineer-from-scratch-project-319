# DevOps Engineer from Scratch — инфраструктура в Yandex Cloud

[![Actions Status](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions)

Terraform-проект разворачивает в Yandex Cloud:

- VPC с подсетью, NAT Gateway и security groups
- Managed Kubernetes (1 worker-нода)
- Managed PostgreSQL 16
- Object Storage (S3-совместимый бакет)
- Lockbox-секрет с параметрами DB/S3

Состояние Terraform хранится в Object Storage (S3 backend), **не в репозитории**.

## Требования к рабочей системе

| Инструмент | Версия | Назначение |
|------------|--------|------------|
| [Terraform](https://www.terraform.io/downloads) | >= 1.5 | Управление инфраструктурой |
| [YC CLI](https://yandex.cloud/ru/docs/cli/quickstart) | latest | Аутентификация в Yandex Cloud |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 | Работа с Kubernetes |
| [make](https://www.gnu.org/software/make/) | любая | Обёртка над командами Terraform |

Доступ к Yandex Cloud: каталог с правами на создание VPC, K8s, MDB, Object Storage, Lockbox.

Для S3 backend нужны статические ключи доступа к бакету `hexlet-project-bucket` (переменные `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`).

## Установка и настройка YC CLI

```bash
# macOS (Homebrew)
brew install yandex-cloud/tap/yc

# Первичная настройка: OAuth, каталог, зона по умолчанию
yc init
```

Аутентификация через IAM-токен (для Terraform и kubectl):

```bash
export YC_TOKEN=$(yc iam create-token)
```

Или через профиль `yc` — Terraform-провайдер подхватит credentials из `~/.config/yandex-cloud/`.

## Подготовка Terraform

```bash
# 1. Скопировать пример переменных
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 2. Задать пароль PostgreSQL и путь к yc в terraform.tfvars

# 3. Экспортировать ключи для S3 backend (state)
export AWS_ACCESS_KEY_ID="<access-key>"
export AWS_SECRET_ACCESS_KEY="<secret-key>"

# 4. IAM-токен для провайдера Yandex
export YC_TOKEN=$(yc iam create-token)
```

## Команды Makefile

```bash
make help              # список всех команд
make init              # terraform init
make validate          # проверка конфигурации
make fmt               # форматирование .tf файлов
make plan              # план изменений
make apply             # развернуть / обновить инфраструктуру
make output            # показать outputs
make output-kubeconfig # сохранить kubeconfig в terraform/config
make destroy           # удалить инфраструктуру
```

Эквивалент без Makefile:

```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform output -raw kubeconfig > config
```

## Подключение к Kubernetes

```bash
make output-kubeconfig
export KUBECONFIG=$(pwd)/terraform/config
kubectl get nodes
kubectl get pods -A
```

Kubeconfig использует `exec`-аутентификацию через `yc k8s create-token` (как `yc managed-kubernetes cluster get-credentials`).

## Outputs

После `terraform apply` доступны:

| Output | Описание |
|--------|----------|
| `k8s_cluster_id` | ID Kubernetes-кластера |
| `k8s_node_group_id` | ID группы worker-нод |
| `k8s_api_endpoint` | URL API-сервера |
| `kubeconfig` | Файл конфигурации kubectl |
| `iam_token` | IAM-токен (краткоживущий) |
| `postgresql_cluster_id` | ID кластера PostgreSQL |
| `postgresql_cluster_fqdn` | FQDN хоста БД |
| `postgresql_connection_string` | Строка подключения (pooler, порт 6432) |
| `s3_bucket` | Имя бакета |
| `s3_access_key` / `s3_secret_key` | Ключи доступа к Object Storage |
| `s3_endpoint` | Endpoint S3 |
| `lockbox_secret_id` | ID Lockbox-секрета с DB/S3 параметрами |

```bash
terraform output k8s_cluster_id
terraform output -raw postgresql_connection_string
terraform output lockbox_secret_id
```

## Структура `terraform/`

```
terraform/
├── versions.tf              # Terraform, провайдер, S3 backend
├── providers.tf             # Провайдер yandex
├── variables.tf             # Входные переменные
├── data.tf                  # Data sources
├── network.tf               # VPC, подсеть, NAT, route table
├── security-group.tf        # Security groups для K8s и PostgreSQL
├── iam.tf                   # Сервисные аккаунты и роли
├── k8s-cluster.tf           # Managed Kubernetes + node group
├── postgresql.tf            # Managed PostgreSQL
├── object-storage-bucket.tf # S3-бакет
├── lockbox.tf               # Lockbox-секрет (DB/S3)
├── outputs.tf               # Выходные значения
└── terraform.tfvars.example # Пример локальных переменных
```

## Сеть и доступ

- VPC `k8s-network`, подсеть `10.2.0.0/16` в `ru-central1-a`
- NAT Gateway для исходящего трафика из подсети
- PostgreSQL доступен из подсети K8s (порт 6432, pooler), без публичного IP
- API Kubernetes доступен с IP из `home-ip` / `office-ip` (переменные)

## Секреты

Не коммитьте:

- `terraform.tfvars` — пароли и локальные пути
- `terraform/config` — kubeconfig
- `.terraform/`, `*.tfstate` — state и провайдеры

Файл `.gitignore` настроен автоматически.
