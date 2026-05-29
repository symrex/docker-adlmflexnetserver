ARG TARGET_TYPE=gcr.io/distroless/base-debian12:nonroot

FROM debian:bookworm-slim AS builder

ARG NLM_URL
ARG TEMP_PATH=/tmp/flexnetserver

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN set -e && apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates cpio rpm2cpio tar wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR $TEMP_PATH

# hadolint ignore=DL3003
RUN set -e; \
    wget --progress=bar:force --output-document=nlm.tar.gz -- "$NLM_URL"; \
    tar -xzf nlm.tar.gz; \
    mkdir -p /staging; \
    rpm2cpio ./*.rpm | (cd /staging && cpio -idmv); \
    mkdir -p /staging/etc /staging/logs /staging/var/flexlm /staging/usr/tmp/.flexlm; \
    mkdir -p /staging/usr/lib/x86_64-linux-gnu; \
    cp /lib/x86_64-linux-gnu/libgcc_s.so.1 /staging/usr/lib/x86_64-linux-gnu/; \
    printf 'lmadmin:x:10001:10001:Autodesk License Manager:/opt/flexnetserver:/sbin/nologin\n' > /staging/etc/passwd; \
    printf 'lmadmin:x:10001:\n' > /staging/etc/group; \
    chmod 1777 /staging/usr/tmp; \
    chown -R 10001:10001 /staging/logs /staging/var/flexlm /staging/usr/tmp/.flexlm; \
    test -x /staging/opt/flexnetserver/lmgrd; \
    test -x /staging/opt/flexnetserver/lmutil

# ============================================
# STAGE 2: TARGET — Selectable via BUILD_ARG
# ============================================
# hadolint ignore=DL3006
FROM ${TARGET_TYPE} AS final

FROM final AS result

ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="docker-adlmflexnetserver" \
      org.opencontainers.image.description="Build recipe for Autodesk Network License Manager / FlexNet in a container" \
      org.opencontainers.image.source="https://github.com/symrex/docker-adlmflexnetserver" \
      org.opencontainers.image.url="https://github.com/symrex/docker-adlmflexnetserver" \
      org.opencontainers.image.documentation="https://github.com/symrex/docker-adlmflexnetserver#readme" \
      org.opencontainers.image.authors="symrex" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-Autodesk-NLM"

COPY --from=builder /staging/ /

EXPOSE 2080
EXPOSE 27000-27009

USER lmadmin:lmadmin
ENTRYPOINT ["/opt/flexnetserver/lmgrd", "-z", "-c", "/opt/flexnetserver/adsk_server.lic"]
