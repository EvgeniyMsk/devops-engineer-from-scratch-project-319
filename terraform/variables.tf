variable "folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
  default     = "b1go4b1b5dslba4uhatp"
}

variable "zone" {
  description = "Зона по умолчанию для провайдера"
  type        = string
  default     = "ru-central1-a"
}

variable "home-ip" {
  description = "IP адрес домашнего компьютера"
  type        = string
  default     = "176.193.106.54/32"
}

variable "office-ip" {
  description = "IP адрес офиса"
  type        = string
  default     = "89.124.73.57/32"
}