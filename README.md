# SMC-Infra

## Overview

This repository manages the infrastructure for the SMC online-code-test platform.

## Repository Structure

```
SMC-Infra/
├── core/
│   └── traefik/                  # Edge proxy + DNS-01 wildcard cert
│       ├── docker-compose.yaml
│       └── .env.example
├── services/
│   └── observe/                  # Observability stack
│       ├── docker-compose.yaml   # Prometheus, Alertmanager, Grafana, Loki, Tempo, Blackbox, Node-exporter
│       ├── config/               # Prometheus / Loki / Tempo configs, alert rules, blackbox targets
│       ├── dashboards/           # Grafana dashboards
│       ├── dashboards.yaml
│       ├── datasources.yaml
│       └── scripts/              # Rule + target generators, hot-reload
├── scripts/
│   ├── core-manager.sh
│   ├── smoke-watchdog.sh         # Smoke test for Watchdog → Healthchecks
│   └── utils.sh
└── Makefile
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
# fill in the values referenced in .env.example

# 2. Start
cd ../..
make core-up
make logs
```

Traefik mints a single **wildcard cert** covering `${DOMAIN}` and `*.${DOMAIN}` (SANs are declared on the dashboard router via `tls.domains`). Every sibling service — `cd.`, `exam.`, `api.`, `grafana.`, ephemeral `pr-N.`, … — reuses that cert as soon as a container with matching Traefik labels joins `smc-traefik`. No per-subdomain DNS-01 dance is required.

## Observability Stack (`services/observe`)

Observability stack including Prometheus, Alertmanager, Grafana, Loki, Tempo, Blackbox exporter, and Node-exporter. Services stay on the internal network.

```bash
cd services/observe
cp .env.default .env          # then edit
docker compose up -d
```

Highlights:

- **Alert rules** for endpoint availability / latency / status-code, SSL-cert expiry, and Node-exporter (Hardware).
- **Blackbox** targets configured under `config/prometheus/targets/`.
- **Alertmanager** routes by severity to Discord (critical + default); webhook URLs live under `config/prometheus/secrets/discord/`
- **Watchdog** — an always-firing Prometheus alert (`vector(1)`) routed through a dedicated `healthchecks` receiver to Healthchecks.io every 15 m. If pings stop arriving, Healthchecks notifies us that the monitoring pipeline itself is down (dead-man's switch).
- **Grafana** dashboards for Prometheus, Alertmanager, Blackbox, and the Node-exporter are provisioned automatically.

## Configuration

See `core/traefik/.env.example` for the variables to set in `core/traefik/.env`.

## Adding a New Subdomain

1. In the target service's `docker-compose.yaml`, join the `smc-traefik` network (declared `external: true`) and add labels:

   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.docker.network=smc-traefik"
     - "traefik.http.routers.<name>.rule=Host(`<name>.${DOMAIN}`)"
     - "traefik.http.routers.<name>.entrypoints=websecure"
     - "traefik.http.routers.<name>.tls.certresolver=cloudflare"
     - "traefik.http.services.<name>.loadbalancer.server.port=<container-port>"
   ```

1. Bring the service up. Traefik discovers the labels and issues a cert on the first request.

## TLS Chain

There are two possible paths depending on whether the DNS record is proxied.

### DNS-only

```
browser --TLS--> Traefik origin
                 (origin cert: Let's Encrypt in acme.json)
```

### Proxied (Cloudflare Proxied)

```
browser --TLS--> Cloudflare edge ---------TLS---> Traefik origin
                 (edge cert: CF Universal SSL)   (origin cert: Let's Encrypt in acme.json)
```
                 
## Notes

Traefik must be running before starting any sibling service that relies on reverse-proxy rules. Without it, routing and TLS termination will not function.
