FROM python:3.12-slim AS builder

ARG PROXY_REPO=https://github.com/The-Bash/ollama-log-proxy.git
ARG PROXY_REF=main

RUN apt-get update \
 && apt-get install -y --no-install-recommends git patch \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "$PROXY_REF" "$PROXY_REPO" .
COPY patches/olm-unraid.patch .
RUN patch -p1 < olm-unraid.patch \
 && rm -f olm-unraid.patch

RUN pip install --no-cache-dir build \
 && python -m build --wheel --outdir /out

FROM python:3.12-slim

WORKDIR /app
COPY --from=builder /out/*.whl /tmp/
RUN pip install --no-cache-dir /tmp/*.whl \
 && rm -rf /tmp/*.whl

# Runs as root: UnRAID appdata is owned nobody:users, a non-root container
# cannot write the SQLite DB on the bind mount.

ENV OLP_PORT=11434
ENV OLP_BACKEND=sqlite
ENV OLP_DB_PATH=/data/ollama-logs.db

EXPOSE 11434 8080 9090

ENTRYPOINT ["ollama-log-proxy"]