# openclaw-intro — project context

## What is this?

Infrastructure for deploying an [OpenClaw](https://openclaw.ai) AI-agent on a Hetzner Cloud VPS.
Stack: **Terraform** (server provisioning) + **Docker Compose** (container runtime) + **Taskfile** (task runner).

OpenClaw gateway runs inside Docker, port `18789` is bound to `127.0.0.1` only — accessible via SSH tunnel.

---

## Key files

| File | Purpose |
|---|---|
| `Dockerfile` | Extends `ghcr.io/openclaw/openclaw:latest` with extra tools (jq, Go, Rust, Bun, pnpm, Homebrew, etc.) |
| `docker-compose.yml` | Two services: `openclaw-gateway` (always on) and `openclaw-cli` (on-demand, profile `cli`) |
| `openclaw.init.json` | **Initial** gateway config — deployed to server only on first `task deploy` (if no config exists yet) |
| `openclaw.json` | **Live** server config — pulled via `task config:pull`, edited locally, pushed back via `task config:sync`. **Not committed** (`.gitignore`d) |
| `.env` | Runtime secrets (`OPENCLAW_GATEWAY_TOKEN`, `TRELLO_API_KEY`, etc.) — **not committed** |
| `Taskfile.yml` | All operational commands (see below) |
| `terraform/` | Hetzner server + firewall + SSH key + cloud-init |

---

## Common commands

```bash
# Infrastructure
task tf:init       # init Terraform
task tf:apply      # create/update Hetzner server
task tf:destroy    # destroy server

# Full deploy (after tf:apply)
task deploy        # copy files → wait for Docker → start OpenClaw

# Day-to-day
task up            # start containers
task down          # stop containers
task restart       # restart gateway
task logs          # follow gateway logs
task status        # show container status
task health        # check /healthz and /readyz

# Config updates
task config:pull   # pull live config from server → local openclaw.json
task config:sync   # push local openclaw.json → server and restart gateway
task env:sync      # sync .env → server and recreate gateway

# Access
task dashboard     # SSH tunnel → http://127.0.0.1:18789
task ssh           # SSH into the server
task exec CMD='docker ps'   # run arbitrary command on server

# Agent
task onboard       # interactive onboarding (first run)
task cli CMD='channels login'  # run openclaw-cli command
```

---

## Environment variables (.env)

```
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
OPENCLAW_GATEWAY_TOKEN=        # auto-generated on first deploy if empty
TRELLO_API_KEY=                # https://trello.com/power-ups/admin
TRELLO_TOKEN=                  # https://trello.com/1/authorize?key=YOUR_KEY&scope=read,write&expiration=never&name=OpenClaw&response_type=token
```

After any `.env` change → run `task env:sync` to apply on the server.

---

## Terraform variables (terraform/terraform.tfvars)

```hcl
hcloud_token        = "..."            # Hetzner API token (Read & Write)
server_type         = "cax11"          # ARM64: 2 vCPU / 4 GB — ~3.79 €/mo
location            = "nbg1"           # nbg1 | fsn1 | hel1
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
ssh_allowed_ips     = ["x.x.x.x/32"]  # restrict SSH to your IP
```

---

## Gateway config (openclaw.json)

- `bind: lan` — listens on all interfaces inside Docker (required when gateway runs behind Docker NAT)
- `allowInsecureAuth: true` and `dangerouslyDisableDeviceAuth: true` — needed because the browser accesses via SSH tunnel, not a paired device
- After editing → run `task config:sync`

---

## Cron jobs (openclaw cron)

Cron commands are run **inside the gateway container** via `task cli CMD='...'` or directly on the server.

Example:
```bash
task cli CMD='cron add \
  --name "Weekly Review" \
  --cron "0 10 * * 1" \
  --tz "Asia/Nicosia" \
  --session isolated \
  --message "..." \
  --announce \
  --channel telegram \
  --to "YOUR_CHAT_ID"'
```

---

## Security notes

- Port `18789` is NOT publicly exposed — SSH tunnel only
- Never commit `terraform/terraform.tfvars` or `.env`
- Restrict `ssh_allowed_ips` in `terraform.tfvars` to your own IP

---

## Typical workflow after a change

1. `task config:pull` — забрать актуальный конфиг с сервера в `openclaw.json`
2. Отредактировать `openclaw.json` локально
3. `task config:sync` — залить обратно и рестартовать gateway
4. `task logs` — убедиться что всё поднялось чисто

> `openclaw.init.json` — начальный шаблон конфига. Используется только командой `task deploy` при первом деплое (когда конфига на сервере ещё нет). Редактировать только для изменения дефолтов нового сервера.

