resource "yandex_lockbox_secret" "app_secrets" {
  name        = "app-secrets"
  description = "Чувствительные параметры приложения (DB/S3) [Hexlet Project]"
  folder_id   = var.folder_id
}

resource "yandex_lockbox_secret_version" "app_secrets_v1" {
  secret_id = yandex_lockbox_secret.app_secrets.id

  entries {
    key        = "docker_oauth_token"
    text_value = var.docker_oauth_token
  }
  entries {
    key        = "STORAGE_S3_ENDPOINT"
    text_value = local.s3_endpoint
  }
  entries {
    key        = "STORAGE_S3_SECRET_KEY"
    text_value = yandex_iam_service_account_static_access_key.iam_bucket_account_key.secret_key
  }
  entries {
    key        = "STORAGE_S3_ACCESS_KEY"
    text_value = yandex_iam_service_account_static_access_key.iam_bucket_account_key.access_key
  }
  entries {
    key        = "STORAGE_S3_BUCKET"
    text_value = yandex_storage_bucket.iam_bucket.bucket
  }
  entries {
    key        = "SPRING_DATASOURCE_URL"
    text_value = "jdbc:postgresql://${yandex_mdb_postgresql_cluster.postgresql_cluster.host[0].fqdn}:${var.postgresql_port}/${var.postgresql_database}?sslmode=require"
  }
  entries {
    key        = "SPRING_DATASOURCE_USERNAME"
    text_value = var.postgresql_user
  }
  entries {
    key        = "SPRING_DATASOURCE_PASSWORD"
    text_value = var.postgresql_password
  }

  depends_on = [
    yandex_iam_service_account_static_access_key.iam_bucket_account_key,
    yandex_storage_bucket.iam_bucket,
    yandex_mdb_postgresql_database.postgresql_database,
  ]
}

resource "yandex_lockbox_secret_iam_member" "app_secrets_k8s_viewer" {
  secret_id = yandex_lockbox_secret.app_secrets.id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}
