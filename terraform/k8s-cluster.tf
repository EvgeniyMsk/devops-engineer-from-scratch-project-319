resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name                    = "k8s-cluster"
  description             = "Kubernetes cluster [Hexlet Project]"
  service_account_id      = yandex_iam_service_account.resource_manager_account.id
  node_service_account_id = yandex_iam_service_account.resource_manager_account.id
  cluster_ipv4_range      = "10.96.0.0/16"
  service_ipv4_range      = "10.112.0.0/16"
  network_id              = yandex_vpc_network.k8s_network.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_clusters_agent,
    yandex_resourcemanager_folder_iam_member.vpc_public_admin,
    yandex_resourcemanager_folder_iam_member.images_puller,
  ]

  master {
    master_location {
      zone      = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.k8s_subnet.id
    }
    security_group_ids = [
      yandex_vpc_security_group.k8s_cluster_nodegroup_traffic.id,
      yandex_vpc_security_group.k8s_cluster_traffic.id
    ]
    public_ip = true
  }
}

resource "yandex_kubernetes_node_group" "worker_nodes_a" {
  cluster_id = yandex_kubernetes_cluster.k8s_cluster.id
  name       = "worker-nodes-a"
  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }
  instance_template {
    platform_id = "standard-v2"

    resources {
      cores  = 2
      memory = 4
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    container_runtime {
      type = "containerd"
    }

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.k8s_subnet.id]
      security_group_ids = [
        yandex_vpc_security_group.k8s_cluster_nodegroup_traffic.id,
        yandex_vpc_security_group.k8s_nodegroup_traffic.id,
        yandex_vpc_security_group.k8s_services_access.id,
        yandex_vpc_security_group.k8s_ssh_access.id
      ]
    }
  }
}
