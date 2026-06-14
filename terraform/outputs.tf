output "k8s-network-id" {
  value = yandex_vpc_network.k8s-network.id
}

output "k8s-subnet-id" {
  value = yandex_vpc_subnet.k8s-subnet.id
}

output "k8s-subnet-zone" {
  value = yandex_vpc_subnet.k8s-subnet.zone
}

output "k8s-subnet-address" {
  value = yandex_vpc_subnet.k8s-subnet.v4_cidr_blocks[0]
}