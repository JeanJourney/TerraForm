# ========================================
#      Terraform - OpenStack Provisioning (multi-instances)
# ========================================

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.44.0"
    }
  }
}

provider "openstack" {
  auth_url    = "https://api.pub1.infomaniak.cloud/identity"
  region      = "dc4-a"
  user_name   = "PCU-E844HLO"
  tenant_name = "PCP-E844HLO"
  password    = "Maxime31072003@"
}

# ==============================
#         Clé SSH
# ==============================
resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = "test"
  public_key = file("~/.ssh/test.pub")

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [public_key]
  }
}

# ==============================
#       Groupe de sécurité
# ==============================
resource "openstack_compute_secgroup_v2" "web_server" {
  name        = "web_server"
  description = "Security Group Description"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 51820
    to_port     = 51820
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

# ==============================
#        Réseau privé
# ==============================
resource "openstack_networking_network_v2" "private_net" {
  name = "private-net"
}

resource "openstack_networking_subnet_v2" "private_subnet" {
  name            = "private-subnet"
  network_id      = openstack_networking_network_v2.private_net.id
  cidr            = "192.168.100.0/24"
  ip_version      = 4
  dns_nameservers = ["1.1.1.1", "8.8.8.8"]
}

# ==============================
#        Variables dynamiques
# ==============================
variable "web_count" {
  default = 2
}

variable "vpn_count" {
  default = 2
}

# ==============================
#        Serveurs Web
# ==============================
resource "openstack_compute_instance_v2" "web_server" {
  count           = var.web_count
  name            = "web-server-${count.index}"
  image_id        = "a0c44881-50cc-4c9d-9753-89206cff776d"
  flavor_name     = "a1-ram2-disk20-perf1"
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
  security_groups = ["web_server"]

  metadata = {
    application = "web-app"
  }

  network {
    name = "ext-net1"
  }

  network {
    uuid        = openstack_networking_network_v2.private_net.id
    fixed_ip_v4 = "192.168.100.${50 + count.index}"
  }
}

# ==============================
#        Serveurs VPN
# ==============================
resource "openstack_compute_instance_v2" "vpn_service" {
  count           = var.vpn_count
  name            = "vpn-service-${count.index}"
  image_id        = "a0c44881-50cc-4c9d-9753-89206cff776d"
  flavor_name     = "a1-ram2-disk20-perf1"
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
  security_groups = ["web_server"]

  metadata = {
    application = "VPN"
  }

  network {
    uuid        = openstack_networking_network_v2.private_net.id
    fixed_ip_v4 = "192.168.100.${50 + count.index}"
  }

  network {
    name = "ext-net1"
  }
}

# ==============================
#             Outputs
# ==============================
output "web_server_ips_public" {
  description = "Liste des IPs publiques des serveurs web"
  value       = [for s in openstack_compute_instance_v2.web_server : s.access_ip_v4]
}

output "web_server_ips_private" {
  description = "Liste des IPs privées des serveurs web"
  value       = [for s in openstack_compute_instance_v2.web_server : s.network[1].fixed_ip_v4]
}

output "vpn_ips_public" {
  description = "Liste des IPs publiques des serveurs VPN"
  value       = [for s in openstack_compute_instance_v2.vpn_service : s.access_ip_v4]
}

output "vpn_ips_private" {
  description = "Liste des IPs privées des serveurs VPN"
  value       = [for s in openstack_compute_instance_v2.vpn_service : s.network[0].fixed_ip_v4]
}
