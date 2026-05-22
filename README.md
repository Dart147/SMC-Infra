# SMC-Infra

## Overview

This repository manages the infrastructure for the SMC online-code-test platform.

## Repository Structure

```
SMC-Infra/
├── core/             # Core edge components
│   └── traefik/
│       ├── docker-compose.yaml
│       ├── .env.example
│       └── letsencrypt/    # cert store; acme.json gitignored
├── scripts/          # Bash helpers invoked by the Makefile
│   ├── core-manager.sh
│   └── utils.sh
└── Makefile          # Unified CLI for common operations
```

## Deployment

### Help message

```bash
make help
```

### Available Make Targets

```
core-up          Start Traefik (creates smc-traefik network if missing)
core-down        Stop Traefik
core-restart     Restart Traefik (stop + start)
logs             Tail Traefik logs
check            Check whether the Traefik container is running
network-init     Create the shared smc-traefik network if it does not already exist
```

## Bringing Up the Edge

```bash
# 1. Configure
cd core/traefik
cp .env.example .env
# edit .env: DOMAIN, CF_DNS_API_TOKEN, TRAEFIK_LE_EMAIL, TRAEFIK_ENABLE_LE=1

# 2. Certification
mkdir -p letsencrypt
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

# 3. Start
cd ../..
make core-up
make logs
```

Subsequent subdomain certs (`cd.${DOMAIN}`, `exam.${DOMAIN}`, …) are
issued automatically the moment a container with matching Traefik labels
joins `smc-traefik`.

## Environment Variables (`core/traefik/.env`)

| Variable | Purpose |
|---|---|
| `DOMAIN` | Apex domain only. Each subdomain prefix lives in the service's Traefik label, not here. |
| `CF_DNS_API_TOKEN` | Cloudflare API token for DNS-01. Zone-scoped. |
| `TRAEFIK_LE_EMAIL` | Contact email for Let's Encrypt. |
| `TRAEFIK_ENABLE_LE` | Set to `1` to enable LE in production. Leave **unset** locally to skip ACME. |
| `TRAEFIK_INSECURE_DASHBOARD` | Set to `true` for local dev only (exposes dashboard on `127.0.0.1:8080`). Leave unset in production. |

## Adding a New Subdomain

1. In the target service's `docker-compose.yaml`, join the `smc-traefik`
   network (declared `external: true`) and add labels:

   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.docker.network=smc-traefik"
     - "traefik.http.routers.<name>.rule=Host(`<name>.${DOMAIN}`)"
     - "traefik.http.routers.<name>.entrypoints=websecure"
     - "traefik.http.routers.<name>.tls.certresolver=cloudflare"
     - "traefik.http.services.<name>.loadbalancer.server.port=<container-port>"
   ```

2. Bring the service up. Traefik discovers the labels and issues a cert on the first request.

## Notes

- The core system (Traefik) must be running before starting any sibling
  service that relies on reverse-proxy rules. Without it, routing and
  TLS termination will not function.
