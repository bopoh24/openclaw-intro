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
├── Dockerfile                # Extends openclaw:latest with extra tools
├── openclaw.init.json        # Initial gateway config (deployed once on first deploy)
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
| `openclaw-gateway` | built from `Dockerfile` (based on `ghcr.io/openclaw/openclaw:latest`) | AI agent gateway + Control UI |
| `openclaw-cli` | same | CLI helper (on-demand) |

The `Dockerfile` extends the base OpenClaw image with extra system packages (`jq`, `golang`, `rust`, `bun`, `pnpm`, `brew`, etc.) required by agent skills.

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

# Trello skill (optional)
TRELLO_API_KEY=                  # from https://trello.com/power-ups/admin
TRELLO_TOKEN=                    # generate at: https://trello.com/1/authorize?key=YOUR_KEY&scope=read,write&expiration=never&name=OpenClaw&response_type=token
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
- Upload `openclaw.init.json` as the initial gateway config **only if no config exists on the server yet** — subsequent deploys leave the live config untouched
- Pull the image and start the container
- Print the server IP and access token when done

---

## Onboarding (connect an agent)

After the first deploy, run onboarding to connect your AI agent to the gateway:

```bash
task onboard
```

This is an interactive process — follow the prompts to:
1. Choose a channel (e.g. Telegram, Discord, etc.)
2. Configure skills (Trello and others will be auto-detected if their env vars are set)
3. Pair the agent with the gateway

> **Note:** If a skill's dependencies are already installed in the Docker image (e.g. `jq` for Trello),  
> it won't appear in the installation step — but it **will** be active and visible in the dashboard.  
> Make sure `TRELLO_API_KEY` and `TRELLO_TOKEN` are set in `.env` before onboarding.

---

## Updating gateway config

The live gateway config lives on the server at `/opt/openclaw/config/openclaw.json` and is managed separately from the repo.

```bash
task config:pull  # 1. download live config from server → local openclaw.json
# edit openclaw.json locally
task config:sync  # 2. upload + restart gateway
task logs         # 3. confirm clean restart
```

`openclaw.json` is in `.gitignore` — it contains credentials and is never committed.  
`openclaw.init.json` is the committed template used only on the very first deploy of a new server.

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
task restart      # restart gateway (does NOT reload .env — use env:sync for that)
task update       # pull latest image and restart
task status       # show container status
task logs         # follow gateway logs
task health       # check /healthz and /readyz endpoints

task env:sync     # sync .env to server and recreate gateway (required after any .env change)
task config:pull  # pull live openclaw.json from server → local file
task config:sync  # push local openclaw.json → server and restart gateway

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
- Never commit `terraform.tfvars`, `.env`, or `openclaw.json` — all are in `.gitignore`

