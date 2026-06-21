resource "yandex_iam_service_account" "resource_manager_account" {
  name        = "resource-manager-account"
  description = "Ресурсный сервисный аккаунт"
}

resource "yandex_iam_service_account" "iam_bucket_account" {
  name        = "iam-bucket-account"
  description = "Сервисный аккаунт для доступа к бакету S3"
}

resource "yandex_iam_service_account_static_access_key" "iam_bucket_account_key" {
  service_account_id = yandex_iam_service_account.iam_bucket_account.id
}

resource "yandex_resourcemanager_folder_iam_member" "iam_bucket_storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.iam_bucket_account.id}"
}

resource "yandex_iam_service_account_iam_member" "iam_bucket_account_member" {
  service_account_id = yandex_iam_service_account.iam_bucket_account.id
  role               = "storage.admin"
  member             = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_clusters_agent" {
  # Сервисному аккаунту назначается роль "k8s.clusters.agent".
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc_public_admin" {
  # Сервисному аккаунту назначается роль "vpc.publicAdmin".
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images_puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "load_balancer_admin" {
  # Нужна для Service type=LoadBalancer (Ingress NGINX → Network Load Balancer).
  folder_id = var.folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "monitoring_editor" {
  # Метрики кластера в Yandex Monitoring / Managed Prometheus.
  folder_id = var.folder_id
  role      = "monitoring.editor"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "logging_writer" {
  # Fluent Bit → Cloud Logging.
  folder_id = var.folder_id
  role      = "logging.writer"
  member    = "serviceAccount:${yandex_iam_service_account.resource_manager_account.id}"
}

resource "yandex_iam_service_account" "eso_service_account" {
  name = "eso-service-account"
}

resource "yandex_lockbox_secret_iam_member" "app_secrets_eso_viewer" {
  secret_id = yandex_lockbox_secret.app_secrets.id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.eso_service_account.id}"
}

resource "yandex_storage_bucket_iam_binding" "iam_bucket_admin" {
  bucket = yandex_storage_bucket.iam_bucket.bucket
  role   = "storage.admin"

  members = [
    "serviceAccount:${yandex_iam_service_account.iam_bucket_account.id}",
  ]

  depends_on = [
    yandex_storage_bucket.iam_bucket,
  ]
}