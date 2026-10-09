# syntax=docker/dockerfile:1

ARG TARGET_TYPE=debian:bookworm-slim

FROM debian:bookworm-slim AS builder

ARG FLEXNET_PACKAGE_URL
ARG TEMP_PATH=/tmp/flexnetserver

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN set -e && apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates cpio rpm2cpio tar unzip wget xz-utils file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR $TEMP_PATH

# Download the vendor FlexNet package and extract it into /staging/opt/flexnetserver.
# Supported archive layouts:
#   - tar.gz/tgz/tar.xz/tbz2 containing *.rpm (Autodesk NLM) -> rpm2cpio extraction
#   - tar.gz/tgz/tar.xz/tbz2 containing plain binaries (some vendors)
#   - zip containing plain binaries, optionally under lnx64.o/ (Xilinx/AMD FlexLM)
# hadolint ignore=DL3003
RUN --mount=from=build-context,target=/packages,source=/ \
    set -e; \
    case "$FLEXNET_PACKAGE_URL" in \
      packages/*) cp "/packages/${FLEXNET_PACKAGE_URL#packages/}" ./package ;; \
      *) wget --progress=bar:force --output-document=package -- "$FLEXNET_PACKAGE_URL" ;; \
    esac; \
    mkdir -p /staging/opt/flexnetserver; \
    if file ./package | grep -qi 'zip archive'; then \
      unzip -o -q ./package -d ./extracted; \
      BIN_DIR="$(find ./extracted -type d -name 'lnx64.o' | head -n 1)"; \
      if [ -n "$BIN_DIR" ]; then \
        cp -a "$BIN_DIR"/. /staging/opt/flexnetserver/; \
      else \
        find ./extracted -type f -exec cp -a {} /staging/opt/flexnetserver/ \; ; \
      fi; \
    else \
      tar -xf ./package; \
      if ls ./*.rpm >/dev/null 2>&1; then \
        rpm2cpio ./*.rpm | (cd /staging && cpio -idmu --quiet); \
      else \
        find . -maxdepth 1 -type f ! -name package -exec cp -a {} /staging/opt/flexnetserver/ \; ; \
      fi; \
    fi; \
    rm -f ./package; \
    chmod 0755 /staging/opt/flexnetserver/* 2>/dev/null || true; \
    test -x /staging/opt/flexnetserver/lmgrd; \
    test -x /staging/opt/flexnetserver/lmutil

# Create the runtime filesystem: generic symlinks for every executable, LSB
# interpreter symlink for vendor binaries linked against /lib64/ld-lsb-x86-64.so.3,
# and a non-root runtime user. The LSB symlink lives in a separate tree because
# BuildKit cannot merge-copy a directory onto the base image's /lib64 symlink
# (cross-platform builds fail with "cannot copy to non-directory").
RUN set -e; \
    mkdir -p /staging/etc /staging/var/flexlm /staging/usr/local/bin /staging/usr/local/flexlm/licenses /staging/usr/tmp/.flexlm /staging/usr/lib/x86_64-linux-gnu /staging-lib64; \
    cp /lib/x86_64-linux-gnu/libgcc_s.so.1 /staging/usr/lib/x86_64-linux-gnu/; \
    for f in /staging/opt/flexnetserver/*; do \
      case "$(basename "$f")" in \
        *.so|*.so.*|*.pdf|*.txt|*.sig) continue ;; \
      esac; \
      if [ -f "$f" ] && [ -x "$f" ]; then \
        ln -s "../../../opt/flexnetserver/$(basename "$f")" "/staging/usr/local/bin/$(basename "$f")"; \
      fi; \
    done; \
    ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /staging-lib64/ld-lsb-x86-64.so.3; \
    printf 'lmadmin:x:10001:10001:FlexNet License Manager:/opt/flexnetserver:/sbin/nologin\n' > /staging/etc/passwd; \
    printf 'lmadmin:x:10001:\n' > /staging/etc/group; \
    chmod 1777 /staging/usr/tmp; \
    chown -R 10001:10001 /staging/var/flexlm /staging/usr/local/flexlm /staging/usr/tmp/.flexlm; \
    test -x /staging/usr/local/bin/lmutil

# ============================================
# STAGE 2: TARGET — Selectable via BUILD_ARG
# ============================================
# hadolint ignore=DL3006
FROM ${TARGET_TYPE} AS final

FROM final AS result

ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="docker-flexnetserver" \
      org.opencontainers.image.description="Build recipe for a vendor FlexNet license server (lmgrd + vendor daemon) in a container" \
      org.opencontainers.image.source="https://github.com/symrex/docker-adlmflexnetserver" \
      org.opencontainers.image.url="https://github.com/symrex/docker-adlmflexnetserver" \
      org.opencontainers.image.documentation="https://github.com/symrex/docker-adlmflexnetserver#readme" \
      org.opencontainers.image.authors="symrex" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-Vendor-FlexNet-Binaries"

COPY --from=builder /staging/ /
COPY --from=builder /staging-lib64/ /lib64/

USER lmadmin:lmadmin
ENTRYPOINT ["/opt/flexnetserver/lmgrd"]
