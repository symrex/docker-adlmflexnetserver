# ============================================
# STAGE 1: BUILDER — Always Debian (RPM Extraction)
# ============================================
FROM debian:bookworm-slim AS builder

LABEL version="1.0" maintainer="symrex"

ARG NLM_URL
ARG TEMP_PATH=/opt/flexnetserver

RUN set -e && apt-get update && apt-get install -y --no-install-recommends \
        wget rpm bsdtar lsb-release \
    && rm -rf /var/lib/apt/lists/*

WORKDIR $TEMP_PATH
RUN wget --progress=bar:force -- $NLM_URL
RUN tar -zxvf ./*.tar.gz

# ============================================
# STAGE 2: TARGET — Selectable via BUILD_ARG
# ============================================
ARG TARGET_TYPE=debian
FROM ${TARGET_TYPE} AS final

# ============================================
# STAGE 3: RESULT — Copies to final
# ============================================
FROM final AS result

COPY --from=builder /opt/flexnetserver /opt/flexnetserver

# Add glibc for Distroless (only if not present)
RUN if [ ! -f /lib64/ld-linux-x86-64.so.2 ]; then \
        mkdir -p /lib64 && \
        cp /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ 2>/dev/null || true; \
    fi

VOLUME ["/opt/flexnetserver"]
EXPOSE 2080
EXPOSE 27000-27009

USER lmadmin
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD lmutil lmstat -a -c /opt/flexnetserver/adsk_server.lic || exit 1
ENTRYPOINT ["lmgrd", "-z", "-c", "/opt/flexnetserver/adsk_server.lic", "@"]
