# ----- Провайдер -----
 terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
}
 
provider "yandex" {
  token     = "y0_A**********************oyYX7w"
  cloud_id  = "b1****o2n"
  folder_id = "b1gi******ih9pad"
  zone      = "ru-central1-a"
}

# ----- Настройка сети -----
resource "yandex_vpc_network" "webdiplom" {
  name = "dilpom-net"
}

# ----- Настройка подсетей -----
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.webdiplom.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet-b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.webdiplom.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

# ----- Группы безопасности -----

# Bastion
resource "yandex_vpc_security_group" "bastion" {
  name        = "bastion"
  description = "Public Group Bastion"
  network_id  = yandex_vpc_network.webdiplom.id

  ingress {
    protocol       = "ANY"
    description    = "Rule description 1"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Rule description 2"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----- Создание ВМ nginx -----

# Bastion
resource "yandex_compute_instance" "bastion" {
  name = "bastion"
  hostname = "bastion"
  zone = "ru-central1-a"

  resources{
    cores = 2
    core_fraction = 20
    memory = 2
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
        security_group_ids = [yandex_vpc_security_group.bastion.id]
  }
  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

