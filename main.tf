terraform {
  required_providers {
    g42cloud = {
      source = "g42cloud-terraform/g42cloud"
      version = "1.3.0"
    }
  }
}

provider "g42cloud" {
  # Configuration options
 project_name="ae-ad-1_Etisalat"
}


data "g42cloud_availability_zones" "myaz" {}

data "g42cloud_compute_flavors" "ccenode" {
  availability_zone = data.g42cloud_availability_zones.myaz.names[0]
  performance_type  = "normal"
  cpu_core_count    = 4
  memory_size       = 8
}


data "g42cloud_compute_flavors" "bastion" {
  availability_zone = data.g42cloud_availability_zones.myaz.names[0]
  performance_type  = "normal"
  cpu_core_count    = 1
  memory_size       = 2
}


data "g42cloud_images_image" "bastion" {
  name        = var.bastion_os
  most_recent = true
}


resource "g42cloud_vpc" "vpc_v1" {
  name = var.vpc_name
  cidr = var.vpc_cidr
}

resource "g42cloud_vpc_subnet" "subnet_v1" {
  name       = var.subnet_name
  cidr       = var.subnet_cidr
  gateway_ip = var.subnet_gateway_ip
  vpc_id     = g42cloud_vpc.vpc_v1.id
  primary_dns = var.primary_dns
  secondary_dns = var.secondary_dns
}

resource "g42cloud_vpc_eip" "eip_natgw" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    share_type = "PER"
    name = "eip-cce-natgw"
    size        = 20
    charge_mode = "traffic"
  }
}


resource "g42cloud_vpc_eip" "eip_bastion" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    share_type = "PER"
    name = "eip-bastion"
    size        = 10
    charge_mode = "traffic"
  }
}

resource "g42cloud_nat_gateway" "nat_cce" {
  name                = "nat_cce"
  description         = "outbound for cce clusters"
  spec                = "1"
  vpc_id              = g42cloud_vpc.vpc_v1.id
  subnet_id           = g42cloud_vpc_subnet.subnet_v1.id
}

resource "g42cloud_nat_snat_rule" "snat_1" {
  nat_gateway_id = g42cloud_nat_gateway.nat_cce.id
  floating_ip_id = g42cloud_vpc_eip.eip_natgw.id
  subnet_id      = g42cloud_vpc_subnet.subnet_v1.id
}

resource "g42cloud_compute_keypair" "keypair-one" {
  name       = "cce-keypair"
  public_key = var.public-key
}

resource "g42cloud_compute_instance" "cce-bastion" {
  name              = "rancher-bastion"
  image_id          = data.g42cloud_images_image.bastion.id
  flavor_id         = data.g42cloud_compute_flavors.bastion.ids[0]
  security_groups   = ["sg-cce-ssh"]
  availability_zone = data.g42cloud_availability_zones.myaz.names[1]
  key_pair          = "cce-keypair"
  system_disk_type  = "SAS"
  system_disk_size  = 40
  user_data = <<EOF
#!/bin/bash
curl -LO https://dl.k8s.io/release/v1.21.7/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl
curl -LO https://get.helm.sh/helm-v3.8.0-linux-amd64.tar.gz
tar -zxvf helm-v3.8.0-linux-amd64.tar.gz
chmod +x linux-amd64/helm
rm helm-v3.8.0-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64
EOF

  network {
    uuid = g42cloud_vpc_subnet.subnet_v1.id
  }
}


resource "g42cloud_compute_eip_associate" "bastion_associated" {
  public_ip   = g42cloud_vpc_eip.eip_bastion.address
  instance_id = g42cloud_compute_instance.cce-bastion.id
}


resource "g42cloud_networking_secgroup" "sg-ssh" {
  name        = "sg-cce-ssh"
  description = "bastion ingress "
}

resource "g42cloud_networking_secgroup_rule" "sg-ssh-rule1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = g42cloud_networking_secgroup.sg-ssh.id
}

resource "g42cloud_cce_cluster" "cce-cluster" {
  name                   = "cce-cluster"
  flavor_id              = "cce.s1.small"
  vpc_id                 = g42cloud_vpc.vpc_v1.id
  subnet_id              = g42cloud_vpc_subnet.subnet_v1.id
  container_network_type = "overlay_l2"
}


resource "g42cloud_cce_node_pool" "node_pool" {
  cluster_id               = g42cloud_cce_cluster.cce-cluster.id
  name                     = "datapool"
  os                       = "CentOS 7.6"
  initial_node_count       = 2
  flavor_id                = "s6.large.4"
  availability_zone        = data.g42cloud_availability_zones.myaz.names[1]
  key_pair                 = "cce-keypair"
  scall_enable             = true
  min_node_count           = 1
  max_node_count           = 10
  scale_down_cooldown_time = 100
  priority                 = 1
  type                     = "vm"

  root_volume {
    size       = 40
    volumetype = "SAS"
  }
  data_volumes {
    size       = 100
    volumetype = "SAS"
  }
}