resource "yandex_mdb_postgresql_cluster" "postgresql-cluster" {
  name                = "postgresql-cluster"
  description         = "PostgreSQL cluster [Hexlet Project]"
  environment         = "PRODUCTION"
  network_id          = yandex_vpc_network.k8s-network.id
  security_group_ids  = [yandex_vpc_security_group.postgresql-traffic.id]
  deletion_protection = false

  config {
    version = "16"
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10
    }
    pooler_config {
      pooling_mode = "SESSION"
    }
  }

  host {
    zone             = var.zone
    name             = "postgresql-host"
    subnet_id        = yandex_vpc_subnet.k8s-subnet.id
    assign_public_ip = false
  }
}

resource "yandex_mdb_postgresql_user" "postgresql-user" {
  cluster_id = yandex_mdb_postgresql_cluster.postgresql-cluster.id
  name       = var.postgresql_user
  password   = var.postgresql_password
}

resource "yandex_mdb_postgresql_database" "postgresql-database" {
  cluster_id = yandex_mdb_postgresql_cluster.postgresql-cluster.id
  name       = var.postgresql_database
  owner      = yandex_mdb_postgresql_user.postgresql-user.name

  depends_on = [
    yandex_mdb_postgresql_user.postgresql-user,
  ]
}
