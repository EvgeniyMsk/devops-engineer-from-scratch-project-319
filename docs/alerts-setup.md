# Алерты Yandex Monitoring — hexlet-project

> Создание: [Monitoring → Алерты](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring/alerts/create)  
> Канал уведомлений: [Каналы](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/monitoring/channels) → `hexlet-email` (Email/Telegram)

```bash
make check-monitoring-queries   # проверить запросы
make open-monitoring-alerts     # открыть форму
```

## Параметры

| Параметр | Значение |
|----------|----------|
| folder_id | `b1gepvj6lg03dc9505kh` |
| cluster_id (Terraform) | `catb3ouu6c06vh9fofit` |
| cluster_id (в метках MKS) | **`k8s-cluster`** — используйте в запросах алертов |
| namespace | `hexlet-project` |
| log group | `k8s-hexlet-logs` |

## Сводная таблица

| # | Алерт | Категория |
|---|-------|-----------|
| 1 | `hexlet-no-metrics-10s` | Доступность |
| 2 | `hexlet-container-restarts` | Restarts |
| 3 | `hexlet-error-logs-5xx` | 5xx / ERROR |
| 4 | `hexlet-db-latency-p95` | Latency |
| 5 | `hexlet-db-avg-query-time` | Latency |
| 6 | `hexlet-pod-high-memory` | Производительность |
| 7 | `hexlet-container-high-cpu` | Производительность |
| 8 | `hexlet-high-network-load` | Нагрузка |
| 9 | `hexlet-master-high-cpu` | Нагрузка |

> Monitoring **требует** хотя бы один порог **Warning** или **Alarm** — иначе ошибка `VALUE_NOT_SPECIFIED`.

> **Имена метрик с точками** — в **двойных кавычках**: `"pod.memory.working_set_bytes"{...}`

> **Не указывайте `folderId` в селекторе запроса.** Каталог задаётся контекстом алерта.  
> С `folderId="..."` в запросе → **0 метрик** → постоянные ложные Alarm (проверено через API).

> **Окно 10s для MKS не подходит:** метрики приходят ~раз в минуту. Окно **10s** почти всегда без точек → срабатывает «Отсутствие точек» → спам. Используйте **3m** или **5m**.

> **IGAUGE-метрики** (`pod.memory.working_set_bytes`) в UI часто показывают «нет точек» при сыром запросе.  
> Используйте **`series_max(...)`** — одна линия с точками на графике. Фильтр **`pod="hexlet-project*"`** — только pod приложения (без acme-solver).

### Проверка запроса перед сохранением алерта

```bash
make check-monitoring-queries
```

**Рабочий запрос** (1 линия, точки на графике за 1–3 ч):

```
series_max("pod.memory.working_set_bytes"{service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project", pod="hexlet-project*"})
```

В Metric Explorer: период **1h** или **3h**, не 15m — если точек всё ещё нет, проверьте запрос выше.

---

## 1. Доступность — нет метрик 10 секунд

**Имя:** `hexlet-no-metrics-10s`  
**Описание:** pod не отдаёт метрики (упал / не Ready).

**Запрос A:**
```
series_max("pod.memory.working_set_bytes"{service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project", pod="hexlet-project*"})
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Last value** (Последнее значение) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | *(можно пусто)* |
| **Alarm** | **`1`** |
| Окно вычисления | **3m** (не 10s — иначе ложные срабатывания) |
| Задержка вычисления | **1m** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **Alarm** |
| Селектор | `{project = "folder__b1gepvj6lg03dc9505kh", cluster = "default", service = "__managed-kubernetes__", namespace = "hexlet-project"}` |
| Отсутствие точек в окне вычисления | **No data** (не Alarm — иначе спам каждую минуту) |

**Уведомления:** канал `hexlet-email`, статусы **Alarm**, **No data**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=no-metrics`.

> **Alarm = 1** — формальный порог. Реальное «pod недоступен» — политика **Отсутствие метрик по селектору = Alarm** (когда pod удалён). Не ставьте **Отсутствие точек = Alarm** при окне короче интервала сбора метрик (~1 мин).

---

## 2. Доступность — перезапуски контейнера (restarts)

**Имя:** `hexlet-container-restarts`  
**Описание:** нестабильный pod (CrashLoopBackOff и т.п.).

**Запрос A:**
```
"container.restart_count"{service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Maximum** (Максимум) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`1`** |
| **Alarm** | **`3`** |
| Окно вычисления | **15m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=restarts`.

> `restart_count` — счётчик с момента старта pod.

---

## 3. 5xx / ошибки — ERROR в Cloud Logging

**Имя:** `hexlet-error-logs-5xx`  
**Описание:** рост ERROR-логов (5xx, исключения Spring Boot) через Fluent Bit.

**Запрос A:**
```
severity_logs_user_ts{service="logging", user_service="k8s-hexlet-logs", severity="ERROR"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Sum** (Сумма) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`1`** |
| **Alarm** | **`5`** |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **OK** |
| Отсутствие точек в окне вычисления | **OK** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=5xx`.

Фильтр 5xx в [Cloud Logging](https://console.yandex.cloud/folders/b1gepvj6lg03dc9505kh/logging/groups/e23c06dnp7m5sr2vai4e):

```
json_payload.kubernetes.namespace_name="hexlet-project" AND (message:" 500 " OR message:" 502 " OR message:" 503 " OR level=ERROR)
```

---

## 4. Latency — P95 запросов PostgreSQL

**Имя:** `hexlet-db-latency-p95`  
**Описание:** высокая задержка запросов к БД (95-й перцентиль).

**Запрос A:**
```
"pooler-query_0.95-postgresql-database-postgresql-user"{service="managed-postgresql"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Last value** (Последнее значение) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`300`** (мс) |
| **Alarm** | **`500`** (мс) |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=latency`.

---

## 5. Latency — среднее время запроса PostgreSQL

**Имя:** `hexlet-db-avg-query-time`  
**Описание:** высокое среднее время запросов к БД.

**Запрос A:**
```
"pooler-avg_query_time"{service="managed-postgresql"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Last value** (Последнее значение) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`150`** (мс) |
| **Alarm** | **`300`** (мс) |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=latency`.

---

## 6. Производительность — высокая память pod

**Имя:** `hexlet-pod-high-memory`  
**Описание:** память pod приложения превышает лимит HPA.

**Запрос A:**
```
series_max("pod.memory.working_set_bytes"{service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project", pod="hexlet-project*"})
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Last value** (Последнее значение) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`402653184`** (384 MiB) |
| **Alarm** | **`471859200`** (450 MiB) |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=memory`.

---

## 7. Производительность — высокий CPU контейнера

**Имя:** `hexlet-container-high-cpu`  
**Описание:** утилизация CPU контейнера близка к limit.

**Запрос A:**
```
"container.cpu.limit_utilization"{service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Last value** (Последнее значение) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`70`** (%) |
| **Alarm** | **`85`** (%) |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=cpu`.

---

## 8. Нагрузка — входящий трафик pod

**Имя:** `hexlet-high-network-load`  
**Описание:** аномальный рост входящего трафика к приложению.

**Запрос A:**
```
"pod.network.received_bytes_count"{service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Maximum** (Максимум) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`5000000`** (~5 MB за окно) |
| **Alarm** | **`20000000`** (~20 MB) |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=network`.

> Счётчик байт; пороги подстройте под baseline в Metric Explorer.

---

## 9. Нагрузка — CPU master Kubernetes

**Имя:** `hexlet-master-high-cpu`  
**Описание:** высокая загрузка CPU master-ноды кластера.

**Запрос A:**
```
"master.cpu.utilization_percent"{service="managed-kubernetes", cluster_id="k8s-cluster"}
```

| Поле | Значение |
|------|----------|
| Запрос для проверки | **A** |
| Функция агрегации | **Last value** (Последнее значение) |
| Функция сравнения | **Greater than** (больше) |
| **Warning** | **`70`** (%) |
| **Alarm** | **`85`** (%) |
| Окно вычисления | **5m** |
| Задержка вычисления | **0** |

**Политики no-data:**

| Политика | Значение |
|----------|----------|
| Отсутствие метрик по селектору | **No data** |
| Отсутствие точек в окне вычисления | **No data** |

**Уведомления:** канал `hexlet-email`, статусы **Warning**, **Alarm**.

**Лейблы:** `project=hexlet`, `env=prod`, `alert=master-cpu`.

---

## Проверка алертов

```bash
make check-monitoring-queries

# Доступность (осторожно — простой):
kubectl scale deployment hexlet-project -n hexlet-project --replicas=0
kubectl scale deployment hexlet-project -n hexlet-project --replicas=1
make rollout-status

kubectl rollout restart deployment/hexlet-project -n hexlet-project
make smoke-test
```

Скриншот → `docs/screenshots/monitoring-alerts.png`.

---

## Устранение ложных алертов

| Симптом | Причина | Исправление |
|---------|---------|-------------|
| Постоянно Alarm / No data | `folderId="..."` **внутри запроса** | Удалить `folderId` из селектора |
| График пустой, 0 линий | то же | Запрос без `folderId`, см. пример выше |
| График пустой / «нет точек» | сырой IGAUGE-запрос | `series_max("pod.memory.working_set_bytes"{..., pod="hexlet-project*"})` |
| Alarm каждую минуту | Окно **10s** + «Отсутствие точек = **Alarm**» | Окно **3m**, no-points → **No data** |
| `Variable 'X.Y' is undefined` | точка в имени метрики | `"metric.name"{...}` в кавычках |

**Проверка через API** (должно быть `series > 0`):

```bash
make check-monitoring-queries
```

---

## Ссылки

- [Метрики MKS](https://yandex.cloud/ru/docs/managed-kubernetes/metrics)
- [Метрики PostgreSQL](https://yandex.cloud/ru/docs/managed-postgresql/metrics)
- [Метрики Logging](https://yandex.cloud/ru/docs/logging/concepts/log-group-metrics)
- [Политики no-data](https://yandex.cloud/ru/docs/monitoring/concepts/alerting/alert#no-data-policy)
