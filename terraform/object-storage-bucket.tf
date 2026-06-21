resource "yandex_storage_bucket" "iam_bucket" {
  bucket    = var.storage_s3_bucket
  folder_id = var.folder_id

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.iam_bucket_storage_admin,
  ]
}
