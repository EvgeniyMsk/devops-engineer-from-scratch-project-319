terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.206.0"
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
