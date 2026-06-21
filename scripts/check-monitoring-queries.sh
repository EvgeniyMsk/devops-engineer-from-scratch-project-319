#!/usr/bin/env bash
# Проверка запросов для алертов Monitoring (доступность, 5xx, latency, restarts, нагрузка).
set -euo pipefail

FOLDER_ID="${FOLDER_ID:-b1gepvj6lg03dc9505kh}"
CLUSTER_ID="${CLUSTER_ID:-catb3ouu6c06vh9fofit}"
NAMESPACE="${NAMESPACE:-hexlet-project}"
LOG_GROUP="${LOG_GROUP:-k8s-hexlet-logs}"

if [ -z "${IAM_TOKEN:-}" ]; then
  if command -v yc >/dev/null 2>&1; then
    IAM_TOKEN="$(yc iam create-token)"
  else
    echo "Задайте IAM_TOKEN или установите yc CLI" >&2
    exit 1
  fi
fi

API="https://monitoring.api.cloud.yandex.net/monitoring/v2/data/read?folderId=${FOLDER_ID}"

check_query() {
  local name="$1"
  local query="$2"
  local agg="${3:-AVG}"
  local to_time from_time
  to_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if date -v-3H >/dev/null 2>&1; then
    from_time="$(date -u -v-3H +"%Y-%m-%dT%H:%M:%SZ")"
  else
    from_time="$(date -u -d '3 hours ago' +"%Y-%m-%dT%H:%M:%SZ")"
  fi
  echo "=== ${name} ==="
  echo "Query: ${query}"
  body="$(jq -n \
    --arg query "$query" \
    --arg fromTime "$from_time" \
    --arg toTime "$to_time" \
    --arg agg "$agg" \
    '{query: $query, fromTime: $fromTime, toTime: $toTime, downsampling: {gridAggregation: $agg, gapFilling: "NULL", maxPoints: "100"}}')"
  if ! resp="$(curl -sf -X POST "${API}" \
    -H "Authorization: Bearer ${IAM_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$body")"; then
    echo "FAIL: запрос не выполнен"
    echo
    return 1
  fi
  count="$(echo "$resp" | jq '[.metrics[]?.timeseries?] | length')"
  points="$(echo "$resp" | jq '[.metrics[]? | (.timeseries.doubleValues // .timeseries.int64Values // []) | length] | add // 0')"
  if [ "$count" -gt 0 ] && [ "$points" -gt 0 ]; then
    echo "OK: ${count} series, ${points} points"
  elif [ "$count" -gt 0 ]; then
    echo "WARN: ${count} series, но 0 points — попробуйте series_max(...) в запросе"
  else
    echo "WARN: нет данных (норма для ERROR-логов, если ошибок не было)"
  fi
  echo
}

POD_MEM='service="managed-kubernetes", cluster_id="k8s-cluster", namespace="hexlet-project", pod="hexlet-project*"'
MKS_Q="service=\"managed-kubernetes\", cluster_id=\"k8s-cluster\", namespace=\"${NAMESPACE}\""
PG_Q="service=\"managed-postgresql\""
LOG_Q="service=\"logging\", user_service=\"${LOG_GROUP}\", severity=\"ERROR\""

echo "Проверка запросов алертов (folder=${FOLDER_ID})"
echo

check_query "1. Доступность — pod memory (series_max)" \
  "series_max(\"pod.memory.working_set_bytes\"{${POD_MEM}})" \
  "AVG"

check_query "2. Restarts" \
  "\"container.restart_count\"{${MKS_Q}}" \
  "MAX"

check_query "3. 5xx / ERROR logs" \
  "severity_logs_user_ts{${LOG_Q}}" \
  "SUM"

check_query "4. Latency P95 (PostgreSQL)" \
  "\"pooler-query_0.95-postgresql-database-postgresql-user\"{${PG_Q}}" \
  "AVG"

check_query "5. Latency avg query (PostgreSQL)" \
  "\"pooler-avg_query_time\"{${PG_Q}}" \
  "AVG"

check_query "6. Память pod (series_max)" \
  "series_max(\"pod.memory.working_set_bytes\"{${POD_MEM}})" \
  "AVG"

check_query "7. CPU контейнера" \
  "\"container.cpu.limit_utilization\"{${MKS_Q}}" \
  "AVG"

check_query "8. Нагрузка — network in" \
  "\"pod.network.received_bytes_count\"{${MKS_Q}}" \
  "MAX"

check_query "9. CPU master" \
  "\"master.cpu.utilization_percent\"{service=\"managed-kubernetes\", cluster_id=\"k8s-cluster\"}" \
  "AVG"

echo "Инструкция по созданию алертов: docs/alerts-setup.md"
