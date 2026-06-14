resource "yandex_lockbox_secret" "app_secrets" {
  name        = "app-secrets"
  description = "Чувствительные параметры приложения (DB/S3) [Hexlet Project]"
  folder_id   = var.folder_id
}

resource "yandex_lockbox_secret_version" "app_secrets_v1" {
  secret_id = yandex_lockbox_secret.app_secrets.id

  entries {
    key        = "DB_HOST"
    text_value = yandex_mdb_postgresql_cluster.postgresql_cluster.host[0].fqdn
  }

  entries {
    key        = "DB_PORT"
    text_value = var.postgresql_port
  }

  entries {
    key        = "DB_NAME"
    text_value = yandex_mdb_postgresql_database.postgresql_database.name
  }

  entries {
    key        = "DB_USER"
    text_value = yandex_mdb_postgresql_user.postgresql_user.name
  }

  entries {
    key        = "DB_PASSWORD"
    text_value = yandex_mdb_postgresql_user.postgresql_user.password
  }

  entries {
    key        = "S3_BUCKET"
    text_value = yandex_storage_bucket.iam_bucket.bucket
  }

  entries {
    key        = "S3_ACCESS_KEY"
    text_value = yandex_iam_service_account_static_access_key.iam_bucket_account_key.access_key
  }

  entries {
    key        = "S3_SECRET_KEY"
    text_value = yandex_iam_service_account_static_access_key.iam_bucket_account_key.secret_key
  }

  entries {
    key        = "S3_ENDPOINT"
    text_value = "https://storage.yandexcloud.net"
  }

  depends_on = [
    yandex_mdb_postgresql_database.postgresql_database,
    yandex_storage_bucket.iam_bucket,
  ]
}

resource "yandex_lockbox_secret_iam_member" "app_secrets_k8s_viewer" {
  secret_id = yandex_lockbox_secret.app_secrets.id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}
