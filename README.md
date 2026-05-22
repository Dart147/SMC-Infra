# SMC-Infra

## Overview

This repository manages the infrastructure for the SMC online-code-test platform.

## Repository Structure

```
SMC-Infra/
├── core/
│   └── traefik/
│       ├── docker-compose.yaml
│       └── .env.example
├── scripts/
│   ├── core-manager.sh
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

Subsequent subdomain certs (`cd.${DOMAIN}`, `exam.${DOMAIN}`, …) are
issued automatically the moment a container with matching Traefik labels
joins `smc-traefik`.

## Configuration

See `core/traefik/.env.example` for the variables to set in
`core/traefik/.env`.

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
