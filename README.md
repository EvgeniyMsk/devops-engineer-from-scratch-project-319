# DevOps Engineer from Scratch — инфраструктура в Yandex Cloud

[![Hexlet Check](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/EvgeniyMsk/devops-engineer-from-scratch-project-319/actions/workflows/hexlet-check.yml)

Приложение: [https://k8s.devops-campus.ru/](https://k8s.devops-campus.ru/)

Terraform поднимает VPC, K8s, PostgreSQL, S3, Lockbox и лог-группу. Приложение bulletin-board ставится Helm-чартом из `k8s/bulletin-board/`; секреты тянет [External Secrets Operator](https://external-secrets.io/) из Lockbox.

State Terraform лежит в Object Storage (`hexlet-bucket`), не в git.

## Инфраструктура

- VPC `k8s-network`, подсеть `10.2.0.0/16`, NAT
- SG `k8s-nodegroup-traffic` — master, ноды, NodePort, SSH, PostgreSQL
- IAM, static key для S3, роли для K8s и Lockbox
- Бакет `hexlet-bucket` — tfstate и файлы приложения
- Lockbox `app-secrets` — DB, S3, Docker OAuth
- Managed K8s `k8s-cluster`, 2 worker-ноды
- Managed PostgreSQL 16, pooler :6432
- Cloud Logging `k8s-hexlet-logs`, Fluent Bit

## Требования

Terraform >= 1.5, [YC CLI](https://yandex.cloud/ru/docs/cli/quickstart), kubectl >= 1.28, Helm >= 3.12, jq, make. AWS CLI — если проверяете S3 backend вручную.

В каталоге нужны права на VPC, Object Storage, Lockbox, IAM, Managed Kubernetes и MDB PostgreSQL.

## Запуск

### YC CLI

```bash
brew install yandex-cloud/tap/yc
yc init
yc config set folder-id b1gepvj6lg03dc9505kh
```

Используйте каталог, где уже есть ресурсы. Каталог в статусе `PENDING_DELETION` не подойдёт.

### Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

В `terraform.tfvars`: `folder_id`, `docker_oauth_token`, `postgresql_password`, `home_ip` / `office_ip` (CIDR `/32`).

`SPRING_DATASOURCE_*` Terraform собирает сам из Managed PostgreSQL. Ключи S3 в tfvars не задаются — static key создаётся в Terraform и уходит в Lockbox.

```bash
export YC_TOKEN=$(yc iam create-token)

export AWS_ACCESS_KEY_ID=$(terraform -chdir=terraform output -raw s3_access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform -chdir=terraform output -raw s3_secret_key)
```

После первого `apply` ключи для S3 backend можно сохранить в `~/.zshrc`.

### Деплой

```bash
make init
make plan
make deploy-all
make output-kubeconfig
export KUBECONFIG=terraform/config
make install-cluster-apps
make install-fluent-bit
make rollout-status
make smoke-test
```

## S3 backend

| Переменная | Для чего |
|------------|----------|
| `YC_TOKEN` | Yandex-провайдер Terraform |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | чтение/запись `terraform.tfstate` в `hexlet-bucket` |

Static key для бакета — SA `iam-bucket-account`, есть в outputs и Lockbox.

## Makefile

Команды из корня репозитория. Полный список: `make help`.

Terraform: `init`, `validate`, `fmt`, `plan`, `apply`, `apply-retry`, `output`, `output-kubeconfig`, `destroy`, `clean`, `deploy-all`.

Kubernetes / Helm: `secret_file`, `secrets-values`, `helm-install`, `helm-upgrade`, `helm-uninstall`, `helm-lint`, `helm-history`, `helm-rollback`, `install-ingress`, `install-cert-manager`, `install-tls`, `install-cluster-apps`, `install-fluent-bit`, `smoke-test`, `rollout-status`, `clean-helm-orphans`.

Values подхватываются в порядке: `values.yaml` → `values.secrets.yaml` → дополнительные `-f` / `--set`.

```bash
helm upgrade --install bulletin-board k8s/bulletin-board \
  -f k8s/bulletin-board/values.yaml \
  -f k8s/bulletin-board/values.secrets.yaml \
  -f k8s/bulletin-board/values.staging.yaml \
  -n hexlet-project

make helm-history
make helm-rollback              # REVISION=3 make helm-rollback
```

CI: [hexlet-check.yml](.github/workflows/hexlet-check.yml). Локально — `make fmt validate helm-lint`. Ещё [validate.yml](.github/workflows/validate.yml), [helm-deploy.yml](.github/workflows/helm-deploy.yml) (ручной запуск).

## Docker Registry

Образ: `cr.yandex/crpd2isbgl7k3puo75s1/project-devops-deploy:latest`

OAuth для pull — в `terraform.tfvars`, дальше Lockbox → ESO → `docker-registry-credentials`. Локально:

```bash
yc iam create-token | docker login cr.yandex --username oauth --password-stdin
```

Node SA с ролью `container-registry.images.puller`; ESO создаёт Secret с OAuth из Lockbox.

## Kubernetes

Нужны: кластер и PostgreSQL после `make apply`, ESO в кластере, metrics-server для HPA, kubeconfig (`make output-kubeconfig`).

Release `bulletin-board`, namespace `hexlet-project`.

| Ресурс | Имя |
|--------|-----|
| Deployment | `hexlet-project` |
| Service | `hexlet-project` :8080 |
| Ingress | `hexlet-project` |
| HPA | `hexlet-project-hpa` — memory 350Mi, 1–2 replicas |
| PDB | `hexlet-project-pdb` |
| SecretStore | `secret-store` |
| ExternalSecret | `app-credentials`, `docker-registry-secret` |
| ConfigMap | `hexlet-project` |

Probes на `/actuator/health:9090`.

```bash
terraform -chdir=terraform output -raw lockbox_secret_id
make helm-install
make install-ingress
```

### Rolling update

`RollingUpdate`, `maxSurge: 1`, `maxUnavailable: 0`, `preStop: sleep 10`.

```bash
make helm-upgrade
make rollout-status
make smoke-test
```

### Доступ

Production: [https://k8s.devops-campus.ru/](https://k8s.devops-campus.ru/) — TLS через cert-manager.

```bash
make install-tls
kubectl get ingress hexlet-project -n hexlet-project
kubectl get certificate -n hexlet-project
```

Port-forward:

```bash
kubectl port-forward -n hexlet-project svc/hexlet-project 8080:8080
```

Actuator — порт 9090.

## Outputs

`kubeconfig`, `k8s_cluster_id`, `k8s_node_group_id`, `k8s_api_endpoint`, `postgresql_cluster_id`, `postgresql_cluster_fqdn`, `postgresql_connection_string`, `s3_bucket`, `s3_access_key`, `s3_secret_key`, `lockbox_secret_id`, `log_group_id`, `log_group_name`, `iam_token` — sensitive где помечено в Terraform.

## Lockbox

| Ключ | Откуда |
|------|--------|
| `docker_oauth_token` | tfvars |
| `STORAGE_S3_*` | Terraform / static key |
| `SPRING_DATASOURCE_*` | Terraform / tfvars |

## Ротация секретов

```bash
yc lockbox secret add-version --id $(terraform -chdir=terraform output -raw lockbox_secret_id) \
  --payload "[{\"key\":\"SPRING_DATASOURCE_PASSWORD\",\"text_value\":\"new-password\"}]"

kubectl annotate externalsecret app-credentials -n hexlet-project \
  force-sync=$(date +%s) --overwrite

kubectl rollout restart deployment/hexlet-project -n hexlet-project
make rollout-status
```

ESO по умолчанию обновляет Secret раз в час (`refreshInterval` в values). Секреты в git не хранятся.

## Мониторинг

Скрины: [screenshots/](screenshots/).

- [Monitoring](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring) — CPU/RAM нод и pod, алерты
- Cloud Logging — после `make install-fluent-bit`, namespace `hexlet-project`
- `kubectl logs -n hexlet-project -l app.kubernetes.io/name=hexlet-application -f`

Проверка запросов алертов: `make check-monitoring-queries`.

```bash
yc logging read --group-id $(terraform -chdir=terraform output -raw log_group_id) \
  --since 1h --filter 'json_payload.kubernetes.namespace_name="hexlet-project"' --limit 10
```

Если log group создавали до Terraform:

```bash
make import-log-group
make apply-retry
```

## Структура

```
.
├── Makefile
├── requirements.txt
├── screenshots/
├── .github/workflows/
├── terraform/
└── k8s/
    ├── fluent-bit/
    └── bulletin-board/
```

## Сеть

VPC `k8s-network`, `10.2.0.0/16`, `ru-central1-a`, NAT. Одна SG (лимит каталога — 5). API K8s и SSH — с `home_ip` / `office_ip`. PostgreSQL :6432 — из подсети K8s.

## Не коммитить

`terraform/terraform.tfvars`, `terraform/config`, `k8s/authorized-key.json`, `k8s/fluent-bit-auth.json`, `k8s/bulletin-board/values.secrets.yaml`, `.terraform/`, `*.tfstate`

## Проблемы

| Ошибка | Что делать |
|--------|------------|
| `SignatureDoesNotMatch` | Обновить AWS-ключи из `terraform output` |
| `PermissionDenied` | `folder_id`, статус каталога |
| `invalid ownership metadata` (helm) | `make clean-helm-orphans`, `make helm-install` |
| ExternalSecret `SecretSyncedError` | `lockboxSecretId`, Secret `yc-auth`, роль `lockbox.payloadViewer` |
| `ImagePullBackOff` | `docker_oauth_token` в Lockbox |
| Ingress без ADDRESS | подождать LB или `make install-ingress` |
| HPA, CPU `<unknown>` | на MKS HPA по memory; CPU в values отключён |
| log group `AlreadyExists` | `make import-log-group`, `make apply-retry` |
