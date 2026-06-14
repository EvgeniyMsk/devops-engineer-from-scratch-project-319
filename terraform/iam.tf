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
