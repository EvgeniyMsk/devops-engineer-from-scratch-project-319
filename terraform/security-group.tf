resource "yandex_vpc_security_group" "k8s-cluster-nodegroup-traffic" {
  name        = "k8s-cluster-nodegroup-traffic"
  description = "Правила группы разрешают служебный трафик для кластера и групп узлов. Примените ее к кластеру и группам узлов."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description       = "Правило для проверок состояния сетевого балансировщика нагрузки."
    from_port         = 0
    to_port           = 65535
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }
  ingress {
    description       = "Правило для входящего служебного трафика между мастером и узлами."
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
  ingress {
    description    = "Правило для проверки работоспособности узлов с помощью ICMP-запросов из подсетей внутри Yandex Cloud."
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  egress {
    description       = "Правило для исходящего служебного трафика между мастером и узлами."
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
}

resource "yandex_vpc_security_group" "k8s-nodegroup-traffic" {
  name        = "k8s-nodegroup-traffic"
  description = "Правила группы разрешают служебный трафик для групп узлов. Примените ее к группам узлов."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Правило для входящего трафика, разрешающее передачу трафика между подами и сервисами."
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["10.96.0.0/16", "10.112.0.0/16"]
  }
  egress {
    description    = "Правило для исходящего трафика, разрешающее узлам в группе узлов подключаться к внешним ресурсам."
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-services-access" {
  name        = "k8s-services-access"
  description = "Правила группы разрешают подключение к сервисам из интернета. Примените ее к группам узлов."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Правило для входящего трафика, разрешающее подключение к сервисам."
    from_port      = 30000
    to_port        = 32767
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-ssh-access" {
  name        = "k8s-ssh-access"
  description = "Правила группы разрешают подключение к узлам по SSH. Примените ее к группам узлов."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Правило для входящего трафика, разрешающее подключение к узлам по SSH."
    port           = 22
    protocol       = "TCP"
    v4_cidr_blocks = ["176.193.106.54/32"]
  }

  ingress {
    description    = "Правило для входящего трафика, разрешающее подключение к узлам по SSH."
    port           = 22
    protocol       = "TCP"
    v4_cidr_blocks = ["89.124.73.57/32"]
  }
}

resource "yandex_vpc_security_group" "k8s-cluster-traffic" {
  name        = "k8s-cluster-traffic"
  description = "Правила группы разрешают трафик для кластера. Примените ее к кластеру."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Правило для входящего трафика, разрешающее доступ к API Kubernetes (порт 443)."
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = [var.home-ip]
  }
  ingress {
    description    = "Правило для входящего трафика, разрешающее доступ к API Kubernetes (порт 443)."
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = [var.office-ip]
  }
  ingress {
    description    = "Правило для входящего трафика, разрешающее доступ к API Kubernetes (порт 6443)."
    port           = 6443
    protocol       = "TCP"
    v4_cidr_blocks = [var.office-ip]
  }
  ingress {
    description    = "Правило для входящего трафика, разрешающее доступ к API Kubernetes (порт 6443)."
    port           = 6443
    protocol       = "TCP"
    v4_cidr_blocks = [var.home-ip]
  }
  egress {
    description    = "Правило для исходящего трафика, разрешающее передачу трафика между мастером и подами metric-server."
    port           = 4443
    protocol       = "TCP"
    v4_cidr_blocks = ["10.96.0.0/16"]
  }
  egress {
    description    = "Правило для исходящего трафика, разрешающее подключение мастера к NTP-серверам для синхронизации времени."
    port           = 123
    protocol       = "UDP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}