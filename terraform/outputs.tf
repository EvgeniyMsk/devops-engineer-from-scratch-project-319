locals {
  k8s_cluster_id    = yandex_kubernetes_cluster.k8s_cluster.id
  k8s_cluster_label = "yc-managed-k8s-${local.k8s_cluster_id}"
  k8s_api_server = "https://${replace(
    yandex_kubernetes_cluster.k8s_cluster.master[0].external_v4_endpoint,
    "https://",
    "",
  )}"
  k8s_ca_cert = yandex_kubernetes_cluster.k8s_cluster.master[0].cluster_ca_certificate

  kubeconfig = <<-EOT
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${base64encode(local.k8s_ca_cert)}
    server: ${local.k8s_api_server}
  name: ${local.k8s_cluster_label}
contexts:
- context:
    cluster: ${local.k8s_cluster_label}
    user: ${local.k8s_cluster_label}
  name: yc-k8s-cluster
current-context: yc-k8s-cluster
kind: Config
preferences: {}
users:
- name: ${local.k8s_cluster_label}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - k8s
      - create-token
      - --profile=${var.yc_profile}
      command: ${var.yc_cli_path}
      env: null
      provideClusterInfo: false
EOT

  postgresql_connection_string = "postgresql://${var.postgresql_user}:${urlencode(var.postgresql_password)}@${yandex_mdb_postgresql_cluster.postgresql_cluster.host[0].fqdn}:${var.postgresql_port}/${var.postgresql_database}?sslmode=require"

  s3_endpoint = "https://storage.yandexcloud.net"
}

output "kubeconfig" {
  description = "Kubeconfig в формате yc get-credentials"
  value       = local.kubeconfig
}

output "iam_token" {
  description = "IAM-токен для kubectl (действует ограниченное время)"
  value       = data.yandex_client_config.client.iam_token
  sensitive   = true
}

output "k8s_cluster_id" {
  description = "ID Kubernetes-кластера"
  value       = yandex_kubernetes_cluster.k8s_cluster.id
}

output "k8s_node_group_id" {
  description = "ID группы worker-нод Kubernetes"
  value       = yandex_kubernetes_node_group.worker_nodes_a.id
}

output "postgresql_cluster_id" {
  description = "ID кластера PostgreSQL"
  value       = yandex_mdb_postgresql_cluster.postgresql_cluster.id
}

output "k8s_api_endpoint" {
  description = "Endpoint Kubernetes API"
  value       = local.k8s_api_server
}

output "postgresql_connection_string" {
  description = "Строка подключения к PostgreSQL"
  value       = local.postgresql_connection_string
  sensitive   = true
}

output "postgresql_cluster_fqdn" {
  description = "FQDN хоста PostgreSQL"
  value       = yandex_mdb_postgresql_cluster.postgresql_cluster.host[0].fqdn
}

output "s3_bucket" {
  description = "Имя S3-бакета"
  value       = yandex_storage_bucket.iam_bucket.bucket
}

output "s3_access_key" {
  description = "Access key для S3"
  value       = yandex_iam_service_account_static_access_key.iam_bucket_account_key.access_key
  sensitive   = true
}

output "s3_secret_key" {
  description = "Secret key для S3"
  value       = yandex_iam_service_account_static_access_key.iam_bucket_account_key.secret_key
  sensitive   = true
}

output "s3_endpoint" {
  description = "Endpoint Object Storage"
  value       = local.s3_endpoint
}

output "lockbox_secret_id" {
  description = "ID Lockbox-секрета с параметрами приложения (DB/S3)"
  value       = yandex_lockbox_secret.app_secrets.id
}
