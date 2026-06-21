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

variable "storage_s3_bucket" {
  description = "Имя S3-бакета"
  type        = string
  default     = "hexlet-bucket"
}

variable "spring_datasource_url" {
  description = "URL для подключения к PostgreSQL"
  type        = string
  default     = "jdbc:postgresql://138.16.178.207:5432/bulletins"
}

variable "spring_datasource_username" {
  description = "Имя пользователя PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "spring_datasource_password" {
  description = "Пароль пользователя PostgreSQL"
  type        = string
  sensitive   = true
} 
