# ollama-log-proxy

A proxy in front of Ollama that logs who calls it. Every inference request
is recorded: which model, how many tokens, and which machine on the network
made the call. Callers keep using the ordinary Ollama API (native and
OpenAI `/v1`); they just point at this host instead of at Ollama itself. A
dashboard and a Prometheus `/metrics` endpoint come with it.

## Why this fork

The upstream project, as released:

- lost all dashboard history on every restart (SQLite was wiped)
- never logged `/v1` OpenAI-compatible calls (classified them as
  non-inference and dropped the rows)
- crashed its background threads under concurrent requests
- could not be stopped cleanly

This fork fixes those. Callers now show by IP, `/v1` streams report real
token counts, the dashboard survives restarts, and the proxy dies only when
you ask it to.

## How the changes are applied

The image is built from source, not pulled. The Dockerfile clones the
upstream repo, applies `patches/olm-unraid.patch`, and runs the install. The
patch is the complete delta between upstream and this fork, reviewable file
by file. Nothing here ships separately from upstream.

## Run it

Needs Docker with compose, and a reachable Ollama server. Replace the
example addresses (RFC 5737 documentation range) with your own.

```bash
cp .env.example .env
# set OLP_OLLAMA_URL to your Ollama, e.g. http://192.0.2.30:11434
docker compose up -d --build
```

Make clients use the proxy instead of Ollama. For Open WebUI, point the base
URL at the proxy: `http://192.0.2.50:11434`. Same for any other client: swap
the Ollama address for the proxy's.

Verify from any machine on the network:

```bash
curl http://192.0.2.50:11434/api/chat \
  -d '{"model":"llama3","messages":[{"role":"user","content":"hi"}]}'
curl http://192.0.2.50:11434/v1/chat/completions \
  -d '{"model":"llama3","messages":[{"role":"user","content":"hi"}]}'
```

What you get:

    http://192.0.2.50:11434          the API proxy (native + /v1)
    http://192.0.2.50:8080           dashboard: callers, models, tokens, history
    http://192.0.2.50:9090/metrics   Prometheus text

Database lives in `./ollama-logs/` and survives restarts. The `/metrics`
counter resets on restart by design; the dashboard history does not.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `OLP_OLLAMA_URL` | `http://host.docker.internal:11434` | Where the proxy sends calls. The default works when Ollama shares the host with Docker; set it for a remote server. |
| `OLP_DASHBOARD_TOKEN` | empty | Password for the dashboard. Empty means open to the network. |
| `OLP_METRICS_TOKEN` | empty | Password for metrics. Empty means open. |
| `PROXY_IP` | - | Only used by the UnRAID macvlan block in the compose file. |
| `DOMAIN`, `SUBDOMAIN` | - | Only used by the UnRAID Traefik block. |

## UnRAID

The compose file runs in plain bridge mode, so `docker compose up` works on
any host. Two commented blocks restore the UnRAID version: a macvlan block
that gives the proxy a static LAN IP (`PROXY_IP`), and a Traefik block that
publishes the dashboard behind wildcard DNS. Commented means unused, so
nothing breaks off UnRAID. On UnRAID, install under
`/boot/config/plugins/compose.manager/projects/ollama-log-proxy/`.

## Update

```bash
docker compose build --no-cache && docker compose up -d
```

## Backup

Back up the bind-mounted directory (`./ollama-logs/` on plain docker, your
appdata path on UnRAID). The whole database is one file.

## Uninstall

```bash
docker compose down --rmi all
rm -rf ./ollama-logs
```

---

Fork of [The-Bash/ollama-log-proxy](https://github.com/The-Bash/ollama-log-proxy)
by Besher Hilal (MIT). See LICENSE.