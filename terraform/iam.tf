resource "yandex_iam_service_account" "resource-manager-account" {
  name        = "resource-manager-account"
  description = "Ресурсный сервисный аккаунт"
}

resource "yandex_iam_service_account" "iam-bucket-account" {
  name        = "iam-bucket-account"
  description = "Сервисный аккаунт для доступа к бакету S3"
}

resource "yandex_iam_service_account_static_access_key" "iam-bucket-account-key" {
  service_account_id = yandex_iam_service_account.iam-bucket-account.id
}

resource "yandex_resourcemanager_folder_iam_member" "iam-bucket-storage-admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.iam-bucket-account.id}"
}

resource "yandex_iam_service_account_iam_member" "iam-bucket-account-member" {
  service_account_id = yandex_iam_service_account.iam-bucket-account.id
  role               = "storage.admin"
  member             = "serviceAccount:${yandex_iam_service_account.resource-manager-account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s-clusters-agent" {
  # Сервисному аккаунту назначается роль "k8s.clusters.agent".
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.resource-manager-account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc-public-admin" {
  # Сервисному аккаунту назначается роль "vpc.publicAdmin".
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.resource-manager-account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.resource-manager-account.id}"
}