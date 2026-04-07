variable "hcloud_token" {
  description = "Hetzner Cloud API token (Settings → API Tokens → Generate)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_ips" {
  description = "IP addresses allowed to connect via SSH (restrict to your own IP for security)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "server_type" {
  description = "Hetzner server type. cax11 (ARM64, 2vCPU/4GB) is sufficient for a single agent"
  type        = string
  default     = "cax11"  # ARM64: 2 vCPU / 4 GB RAM / 40 GB — ~3.79 €/mo
}

variable "location" {
  description = "Hetzner datacenter: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki)"
  type        = string
  default     = "nbg1"
}
