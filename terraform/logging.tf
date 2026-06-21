# Лог-группа создана вручную ранее — import подхватывает её в state (повторный apply безопасен).
import {
  to = yandex_logging_group.k8s_logs
  id = "e23c06dnp7m5sr2vai4e"
}

resource "yandex_logging_group" "k8s_logs" {
  name             = var.log_group_name
  folder_id        = var.folder_id
  retention_period = var.log_retention_period
}
