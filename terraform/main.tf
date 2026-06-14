terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    bucket                      = "hexlet-project-bucket"
    region                      = "ru-central1"
    key                         = "terraform/terraform.tfstate"
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "yandex" {
  folder_id = var.folder_id
  zone      = var.zone
}