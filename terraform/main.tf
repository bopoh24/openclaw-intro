terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
  required_version = ">= 1.5"
}

provider "hcloud" {
  token = var.hcloud_token
}

# SSH key
resource "hcloud_ssh_key" "default" {
  name       = "openclaw-key"
  public_key = file(var.ssh_public_key_path)
}

# Firewall
resource "hcloud_firewall" "openclaw" {
  name = "openclaw-firewall"

  # SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_allowed_ips
  }

  # HTTP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Server
resource "hcloud_server" "openclaw" {
  name        = "openclaw"
  server_type = var.server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]

  firewall_ids = [hcloud_firewall.openclaw.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = file("${path.module}/cloud-init.yml")

  labels = {
    service = "openclaw"
    env     = "production"
  }
}


