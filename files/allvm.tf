# ----- Группы безопасности -----

#Nginx
resource "yandex_vpc_security_group" "nginx" {
  name        = "priv-nginx"
  description = "Private Group Nginx"
  network_id  = yandex_vpc_network.webdiplom.id

  ingress {
    protocol       = "ANY"
    description    = "Rule description 1"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Rule description 2"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#Elastic
resource "yandex_vpc_security_group" "elastic" {
  name        = "priv-elastic"
  description = "Private Group Elasticsearch"
  network_id  = yandex_vpc_network.webdiplom.id


  ingress {
    protocol       = "ANY"
    description    = "Rule description 1"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Rule description 2"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#Zabbix-server
resource "yandex_vpc_security_group" "zabbix" {
  name        = "pub-zabbix"
  description = "Public Group Zabbix"
  network_id  = yandex_vpc_network.webdiplom.id

  ingress {
    protocol       = "ANY"
    description    = "Connect to Zabbix-server"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Out connect"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#Kibana
resource "yandex_vpc_security_group" "kibana" {
  name        = "pub-kibana"
  description = "Public Group Kibana"
  network_id  = yandex_vpc_network.webdiplom.id

  ingress {
    protocol       = "ANY"
    description    = "Connect to Kibana"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Out connect"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

#L7-balance
resource "yandex_vpc_security_group" "balance" {
  name        = "pub-balance"
  description = "Public Group L7-balance"
  network_id  = yandex_vpc_network.webdiplom.id

  ingress {
    protocol          = "TCP"
    description       = "Health check"
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol       = "ANY"
    description    = "Connect to Balance"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  egress {
    protocol       = "ANY"
    description    = "Out connect"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----- Создание ВМ nginx -----

# Nginx-1
resource "yandex_compute_instance" "nginx-1" {
  name = "nginx-1"
  hostname = "nginx-1"
  zone = "ru-central1-a"
  
  resources{
    cores = 2
    core_fraction = 5
    memory = 1
  }

  boot_disk{
    initialize_params {
      image_id = "fd8ecgtorub9r4609man"
      size = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat = false
    security_group_ids = [yandex_vpc_security_group.nginx.id]
  }
  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

#Nginx-2
resource "yandex_compute_instance" "nginx-2" {
  name = "nginx-2"
  hostname = "nginx-2"
  zone = "ru-central1-b"
  
  resources{
    cores = 2
    core_fraction = 5
    memory = 1
  }

  boot_disk{
    initialize_params {
      image_id = "fd8ecgtorub9r4609man"
      size = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-b.id
    nat = false
    security_group_ids = [yandex_vpc_security_group.nginx.id]
  }
  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

# ----- Target Group -----
resource "yandex_alb_target_group" "target-group" {
  name = "target-group"

  target {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    ip_address = yandex_compute_instance.nginx-1.network_interface.0.ip_address
  }

  target {
    subnet_id    = yandex_vpc_subnet.subnet-b.id
    ip_address   = yandex_compute_instance.nginx-2.network_interface.0.ip_address
  }
}

# ----- Backend -----
resource "yandex_alb_backend_group" "backend-group" {
  name = "backend-group"

  http_backend {
    name                   = "backend"
    weight                 = 1
    port                   = 80
    target_group_ids       = [yandex_alb_target_group.target-group.id]
    load_balancing_config {
      panic_threshold      = 90
    }    
    healthcheck {
      timeout              = "10s"
      interval             = "2s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15 
      http_healthcheck {
        path               = "/"
      }
    }
  }
}

# ----- HTTP router -----
resource "yandex_alb_http_router" "http-router" {
  name          = "http-router"
  labels        = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_virtual_host" "my-virtual-host" {
  name                    = "my-virtual-host"
  http_router_id          = yandex_alb_http_router.http-router.id
  route {
    name                  = "my-way"
    http_route {
      http_route_action {
        backend_group_id  = yandex_alb_backend_group.backend-group.id
        timeout           = "60s"
      }
    }
  }
}    

# ----- L-7 Balance -----
resource "yandex_alb_load_balancer" "balancer" {
  name        = "balancer"
  network_id  = yandex_vpc_network.webdiplom.id
  security_group_ids = [yandex_vpc_security_group.balance.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }
  }

  listener {
    name = "listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.http-router.id
      }
    }
  }
}

# ----- VM Zabbix -----

resource "yandex_compute_instance" "zabbix" {
  name = "zabbix"
  hostname = "zabbix-server"
  zone = "ru-central1-a"

  resources{
    cores = 2
    core_fraction = 20
    memory = 4
  }

  boot_disk{
    initialize_params {
      image_id = "fd8ecgtorub9r4609man"
      size = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat = true
        security_group_ids = [yandex_vpc_security_group.zabbix.id]
  }
  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

# ----- VM Elastic -----
resource "yandex_compute_instance" "elastic" {
  name = "elastic"
  hostname = "elastic"
  zone = "ru-central1-a"

  resources{
    cores = 2
    core_fraction = 20
    memory = 4
  }

  boot_disk{
    initialize_params {
      image_id = "fd8ecgtorub9r4609man"
      size = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat = true
        security_group_ids = [yandex_vpc_security_group.elastic.id]
  }
  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

# ----- Kibana -----
resource "yandex_compute_instance" "kibana" {
  name = "kibana"
  hostname = "kibana"
  zone = "ru-central1-a"

  resources{
    cores = 2
    core_fraction = 20
    memory = 6
  }

  boot_disk{
    initialize_params {
      image_id = "fd8ecgtorub9r4609man"
      size = 10
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat = true
        security_group_ids = [yandex_vpc_security_group.kibana.id]
  }
  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

