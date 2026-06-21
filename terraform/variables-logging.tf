variable "log_group_name" {
  description = "Имя лог-группы Cloud Logging для логов K8s"
  type        = string
  default     = "k8s-hexlet-logs"
}

variable "log_retention_period" {
  description = "Срок хранения логов (ISO 8601 duration, напр. 168h = 7 дней)"
  type        = string
  default     = "168h"
}
