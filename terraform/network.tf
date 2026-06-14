resource "yandex_vpc_network" "k8s-network" {
  name        = "k8s-network"
  description = "Network for k8s cluster [Hexlet Project]"
  labels = {
    environment = "production"
  }
}

resource "yandex_vpc_subnet" "k8s-subnet" {
  name           = "k8s-subnet"
  v4_cidr_blocks = ["10.2.0.0/16"]
  description    = "Subnet for k8s cluster [Hexlet Project]"
  labels = {
    environment = "production"
  }
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name      = "nat-gateway"
  folder_id = var.folder_id
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "nat-route-table"
  folder_id  = var.folder_id
  network_id = yandex_vpc_network.k8s-network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}