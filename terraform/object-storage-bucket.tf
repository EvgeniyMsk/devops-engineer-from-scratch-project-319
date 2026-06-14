resource "yandex_storage_bucket" "iam-bucket" {
  bucket     = "iam-bucket"
  folder_id  = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.iam-bucket-account-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.iam-bucket-account-key.secret_key

  depends_on = [
    yandex_resourcemanager_folder_iam_member.iam-bucket-storage-admin,
  ]
}
