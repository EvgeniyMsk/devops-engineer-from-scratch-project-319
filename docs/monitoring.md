# Мониторинг и логирование

## Метрики (Yandex Monitoring)

**Консоль:** [Monitoring](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring)

**Кластер:** [Managed Kubernetes → k8s-cluster → Мониторинг](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/managed-kubernetes)

### Отслеживаемые показатели

| Категория | Метрика | Источник |
|-----------|---------|----------|
| Доступность | нет метрик pod, restarts | MKS `managed-kubernetes` |
| 5xx / ошибки | ERROR-логи | Cloud Logging `severity_logs_user_ts` |
| Latency | P95 / avg query time | Managed PostgreSQL `pooler-query_*` |
| Производительность | CPU/RAM pod | MKS |
| Нагрузка | network bytes, CPU master | MKS |

### Алерты

**Полная инструкция:** [alerts-setup.md](./alerts-setup.md) — 9 алертов с готовыми запросами.

```bash
make check-monitoring-queries
make open-monitoring-alerts
```

| Алерт | Категория |
|-------|-----------|
| `hexlet-no-metrics-10s` | Доступность |
| `hexlet-container-restarts` | Restarts |
| `hexlet-error-logs-5xx` | 5xx / ERROR |
| `hexlet-db-latency-p95` | Latency |
| `hexlet-db-avg-query-time` | Latency |
| `hexlet-pod-high-memory` | Производительность |
| `hexlet-container-high-cpu` | Производительность |
| `hexlet-high-network-load` | Нагрузка |
| `hexlet-master-high-cpu` | Нагрузка |

### Скриншоты для README

1. `docs/monitoring-dashboard.png` — дашборд MKS
2. `docs/monitoring-alerts.png` — список алертов
3. `docs/logging-cloud.png` — логи Cloud Logging

```bash
yc logging read --group-id $(terraform -chdir=terraform output -raw log_group_id) \
  --since 1h --filter 'json_payload.kubernetes.namespace_name="hexlet-project"' --limit 10
```

## Логи (Cloud Logging)

**Лог-группа:** `k8s-hexlet-logs` (Terraform output `log_group_id`)

```bash
make install-fluent-bit
```

Фильтры:

```
json_payload.kubernetes.namespace_name="hexlet-project"
level=ERROR
```

## Импорт лог-группы в Terraform

```bash
make import-log-group
make apply-retry
```
