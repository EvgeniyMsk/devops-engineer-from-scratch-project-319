variable "folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
  default     = "b1gepvj6lg03dc9505kh"
}

variable "zone" {
  description = "Зона по умолчанию для провайдера"
  type        = string
  default     = "ru-central1-a"
}

variable "home_ip" {
  description = "IP адрес домашнего компьютера"
  type        = string
  default     = "176.193.106.54/32"
}

variable "office_ip" {
  description = "IP адрес офиса"
  type        = string
  default     = "178.177.19.99/32"
}

variable "postgresql_user" {
  description = "Имя пользователя PostgreSQL"
  type        = string
  default     = "postgresql-user"
}

variable "postgresql_database" {
  description = "Имя базы данных PostgreSQL"
  type        = string
  default     = "postgresql-database"
}

variable "postgresql_password" {
  description = "Пароль пользователя PostgreSQL (задайте в terraform.tfvars, попадает в Lockbox)"
  type        = string
  sensitive   = true
}

variable "postgresql_port" {
  description = "Порт подключения к PostgreSQL через pooler"
  type        = string
  default     = "6432"
}

variable "yc_cli_path" {
  description = "Путь к CLI yc для kubeconfig (как в yc get-credentials)"
  type        = string
  default     = "yc"
}

variable "yc_profile" {
  description = "Профиль yc для kubeconfig"
  type        = string
  default     = "default"
}

variable "docker_oauth_token" {
  description = "OAuth-токен для доступа к Docker Registry (попадает в Lockbox)"
  type        = string
  sensitive   = true
}

variable "storage_s3_endpoint" {
  description = "Endpoint для S3"
  type        = string
  default     = "https://storage.yandexcloud.net"
}

# variable "storage_s3_access_key" {
#   description = "Access key для S3"
#   type        = string
#   sensitive   = true
# }

# variable "storage_s3_secret_key" {
#   description = "Secret key для S3"
#   type        = string
#   sensitive   = true
# }

variable "storage_s3_bucket" {
  description = "Имя S3-бакета"
  type        = string
  default     = "hexlet-bucket"
}

variable "log_group_name" {
  description = "Имя лог-группы Cloud Logging для логов K8s"
  type        = string
  default     = "k8s-hexlet-logs"
}

variable "log_retention_period" {
  description = "Срок хранения логов (например 168h = 7 дней)"
  type        = string
  default     = "168h"
}
