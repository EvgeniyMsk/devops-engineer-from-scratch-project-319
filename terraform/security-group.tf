# Одна SG — лимит каталога vpc.securityGroups.count = 5.

resource "yandex_vpc_security_group" "k8s_nodegroup_traffic" {
  name        = "k8s-nodegroup-traffic"
  description = "Единая SG: master, узлы, NodePort, SSH, PostgreSQL."
  network_id  = yandex_vpc_network.k8s_network.id

  ingress {
    description       = "Healthchecks балансировщика"
    from_port         = 0
    to_port           = 65535
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }
  ingress {
    description       = "Служебный трафик внутри SG"
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
  ingress {
    description    = "ICMP healthcheck"
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  ingress {
    description    = "API Kubernetes (443)"
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = [var.home_ip, var.office_ip]
  }
  ingress {
    description    = "API Kubernetes (6443)"
    port           = 6443
    protocol       = "TCP"
    v4_cidr_blocks = [var.home_ip, var.office_ip]
  }
  ingress {
    description    = "Трафик между подами и сервисами"
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["10.96.0.0/16", "10.112.0.0/16"]
  }
  ingress {
    description    = "HTTP/HTTPS для Ingress LoadBalancer"
    from_port      = 80
    to_port        = 443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "NodePort сервисы"
    from_port      = 30000
    to_port        = 32767
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "SSH к узлам"
    port           = 22
    protocol       = "TCP"
    v4_cidr_blocks = [var.home_ip, var.office_ip]
  }
  ingress {
    description    = "PostgreSQL из подсети K8s (6432 — pooler)"
    port           = 6432
    protocol       = "TCP"
    v4_cidr_blocks = ["10.2.0.0/16"]
  }
  ingress {
    description    = "PostgreSQL из домашней/офисной подсети (6432 — pooler)"
    port           = 6432
    protocol       = "TCP"
    v4_cidr_blocks = [var.home_ip, var.office_ip]
  }
  egress {
    description       = "Служебный трафик внутри SG"
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
  egress {
    description    = "Master → metric-server"
    port           = 4443
    protocol       = "TCP"
    v4_cidr_blocks = ["10.96.0.0/16"]
  }
  egress {
    description    = "NTP"
    port           = 123
    protocol       = "UDP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description    = "Исходящий трафик"
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
