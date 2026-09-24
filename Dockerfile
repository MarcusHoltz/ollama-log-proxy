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

# Run as an unprivileged user so files written to the bind mount land as a
# normal UID and stay deletable by the host user. Match this user's UID/GID
# to the appdata folder owner via compose `user:`: 1000:1000 for the default
# ./ollama-logs mount, 99:100 (nobody:users) on UnRAID appdata. "app" (not
# proxy: Debian already ships a proxy group).
RUN groupadd -g 1000 app \
 && useradd -m -u 1000 -g 1000 app

USER app

ENV OLP_PORT=11434
ENV OLP_BACKEND=sqlite
ENV OLP_DB_PATH=/data/ollama-logs.db

EXPOSE 11434 8080 9090

ENTRYPOINT ["ollama-log-proxy"]