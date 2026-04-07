# openclaw-intro

Infrastructure for deploying [OpenClaw](https://openclaw.ai) agent on a [Hetzner Cloud](https://www.hetzner.com/cloud) VPS using Terraform + Docker.

The server is provisioned automatically via Terraform. OpenClaw runs in Docker and is accessible securely through an SSH tunnel — no public port exposure.

---

## Prerequisites

Install the following tools on your Mac:

```bash
# Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Terraform — infrastructure provisioning
brew install terraform

# Task — task runner (Taskfile)
brew install go-task

# SSH key — if you don't have one yet
ssh-keygen -t ed25519 -C "your@email.com"
```

You will also need:
- A **Hetzner Cloud** account → [console.hetzner.cloud](https://console.hetzner.cloud)
- A Hetzner **API token**: Project → Security → API Tokens → Generate (Read & Write)

---

## Project structure

```
.
├── docker-compose.yml        # OpenClaw gateway + CLI services
├── .env.example              # Environment variables template
├── .env                      # Your local env (not committed)
├── Taskfile.yml              # All commands (deploy, ssh, logs, etc.)
└── terraform/
    ├── main.tf               # Hetzner server + firewall + SSH key
    ├── variables.tf          # Input variables
    ├── outputs.tf            # Server IP, SSH command
    ├── cloud-init.yml        # Server bootstrap: Docker, ufw, git
    ├── terraform.tfvars      # Your secrets (not committed)
    └── terraform.tfvars.example
```

**What gets deployed on the server:**

| Container | Image | Role |
|---|---|---|
| `openclaw-gateway` | `ghcr.io/openclaw/openclaw:latest` | AI agent gateway + Control UI |
| `openclaw-cli` | same | CLI helper (on-demand) |

Port `18789` is bound to `127.0.0.1` on the server — accessible only via SSH tunnel.

---

## Setup

### 1. Configure Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
hcloud_token = "your-hetzner-api-token"
```

Optional overrides (defaults are fine to start):

```hcl
server_type         = "cax11"            # ARM64: 2 vCPU / 4 GB / 40 GB — ~3.79 €/mo
location            = "nbg1"             # nbg1 · fsn1 · hel1
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
ssh_allowed_ips     = ["1.2.3.4/32"]    # restrict SSH to your IP (recommended)
```

### 2. Configure environment

```bash
cp .env.example .env
```

`OPENCLAW_GATEWAY_TOKEN` can be left empty — it will be auto-generated on first deploy.  
Set it manually if you want a fixed token:

```bash
# .env
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_GATEWAY_TOKEN=          # leave empty OR paste your own
```

### 3. Initialize Terraform

```bash
task tf:init
```

---

## Deploy

```bash
task tf:apply    # provision server on Hetzner (~1 min)
task deploy      # copy files, wait for Docker, start OpenClaw (~3-5 min)
```

`task deploy` is fully automated — it will:
- Wait for SSH to become available
- Wait for cloud-init to finish installing Docker
- Auto-generate `OPENCLAW_GATEWAY_TOKEN` if empty
- Clean up stale SSH known_hosts entries
- Write `openclaw.json` with correct bind mode before container start
- Pull the image and start the container
- Print the server IP and access token when done

---

## Access Control UI

```bash
task dashboard
```

Opens an SSH tunnel and keeps it running. While it's open, visit:

```
http://127.0.0.1:18789
```

Paste `OPENCLAW_GATEWAY_TOKEN` from your `.env` into Settings when prompted.  
Press `Ctrl+C` to close the tunnel.

---

## Available commands

```bash
task deploy       # full deploy from scratch
task dashboard    # SSH tunnel → http://127.0.0.1:18789

task up           # start containers
task down         # stop containers
task restart      # restart gateway
task update       # pull latest image and restart
task status       # show container status
task logs         # follow gateway logs
task health       # check /healthz and /readyz endpoints

task cli CMD='channels login'   # run openclaw-cli command

task ssh          # SSH into the server
task exec CMD='docker ps'       # run a command on the server

task tf:plan      # preview infrastructure changes
task tf:apply     # create / update server
task tf:destroy   # destroy server
task tf:output    # show server IP
```

---

## Full reset

```bash
task tf:destroy   # delete server
task tf:apply     # create new server
task deploy       # redeploy OpenClaw
```

---

## Security notes

- Port `18789` is **not** exposed publicly — SSH tunnel only
- Restrict `ssh_allowed_ips` to your own IP in `terraform.tfvars`
- Never commit `terraform.tfvars` or `.env` — both are in `.gitignore`

