# docker-adlmflexnetserver

[![CI](https://github.com/symrex/docker-adlmflexnetserver/actions/workflows/build.yml/badge.svg)](https://github.com/symrex/docker-adlmflexnetserver/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Unofficial, vendor-neutral container image for running a FlexNet license
> server (`lmgrd` + vendor daemon) for any vendor whose FlexNet package can be
> supplied as a download URL or a local file.

The repository provides a single Docker-based deployment pattern for
environments that operate FlexNet network licenses as managed infrastructure.
The vendor FlexNet package is selected at build time via `FLEXNET_PACKAGE_URL`
in `.env`; license files stay outside the image and are mounted read-only at
runtime.

This project is not affiliated with Autodesk, AMD/Xilinx, MathWorks or Flexera.
It does not provide license entitlements. Vendor FlexNet binaries are
redistribution-restricted: the CI workflow builds and validates images but does
not publish them to a registry, and packages that require a vendor login are
never committed to this repository.

## Supported Vendors

| Vendor | Package | Source | Status |
| --- | --- | --- | --- |
| Autodesk | NLM (`nlm*.tar.gz`, contains RPMs) | public download | tested |
| AMD/Xilinx | `linux_flexlm__v*.zip` | AMD account required, place in `packages/` | tested |
| MathWorks | MATLAB License Manager | MathWorks account | planned |

## Runtime Contract

| Item | Value |
| --- | --- |
| License server manager | `lmgrd` (starts the vendor daemon from the license file's `VENDOR` line) |
| Default license path | `/usr/local/flexlm/licenses/license.dat` |
| Default log target | Docker stdout/stderr (`docker compose logs`) |
| License manager port | `2100` (configurable via `FLEXNET_PORT`) |
| Vendor daemon port | dynamic; publish it only if your network setup requires it (pin with `VENDOR <name> PORT=<port>` in the license file) |
| Runtime user | `lmadmin` (uid/gid 10001) |
| Default Compose command | `-z -datestamp` |
| Compose health check | `lmutil lmstat -c /usr/local/flexlm/licenses/license.dat` |

The container hostname and MAC address must match the values used when the
vendor license file was generated. If the license file pins different ports,
publish those ports instead of the default above.

## Quick Start

```bash
git clone https://github.com/symrex/docker-adlmflexnetserver.git
cd docker-adlmflexnetserver

cp example.env .env
cp /path/to/license.lic licenses/latest.lic
chmod 0444 licenses/latest.lic
```

Edit `.env`:

```dotenv
FLEXNET_PACKAGE_URL=https://damassets.autodesk.net/content/dam/autodesk/www/files/linux/nlm11.19.9.0_ipv4_ipv6_linux64.tar.gz
FLEXNET_HOSTNAME=name_registered_with_vendor
FLEXNET_MAC_ADDRESS=XX:XX:XX:XX:XX:XX
```

Build and start:

```bash
docker compose up --build -d
```

Check status:

```bash
docker compose ps
docker compose logs --tail=100 flexnet
docker compose exec flexnet lmutil lmstat -a -c /usr/local/flexlm/licenses/license.dat
```

## Vendor Packages

`FLEXNET_PACKAGE_URL` accepts two kinds of values:

1. **Public HTTPS URL** — the package is downloaded during the image build
   (Autodesk NLM works this way).
2. **Local file reference** — `packages/<filename>` for packages that are only
   downloadable behind a vendor login (AMD/Xilinx FlexLM, MATLAB). Place the
   file in `./packages/` before building; the directory is git-ignored.

The Dockerfile detects the archive layout automatically:

- `tar.gz`/`tar.xz`/`tar.bz2` containing `*.rpm` → extracted with `rpm2cpio`
  (Autodesk NLM layout)
- `zip` containing an `lnx64.o/` directory → binaries copied from there
  (AMD/Xilinx FlexLM layout)
- any other tar/zip → all contained files are used as-is

The build fails early if the package does not contain `lmgrd` and `lmutil`.

## Configuration

The Compose file reads runtime values from `.env`.

| Variable | Required | Purpose |
| --- | --- | --- |
| `FLEXNET_PACKAGE_URL` | yes for builds | Vendor FlexNet package (HTTPS URL or `packages/<file>`). |
| `FLEXNET_HOSTNAME` | yes | Hostname used by the vendor license file. |
| `FLEXNET_MAC_ADDRESS` | yes | MAC address / host ID registered for the license server. |
| `FLEXNET_PORT` | optional | Host-side port published for `lmgrd`. Defaults to `2100`. |
| `FLEXNET_IMAGE` | optional | Local image tag used by Docker Compose. |
| `FLEXNET_PLATFORM` | optional | Build and runtime platform. Defaults to `linux/amd64`, matching the vendor Linux packages. |
| `FLEXNET_COMMAND` | optional | Extra runtime arguments for `lmgrd`. |

Treat license files and `.env` as sensitive operational material.

## Build Targets

The Dockerfile uses a Debian bookworm builder stage to download and extract the
vendor FlexNet package. The final stage is selected with `TARGET_TYPE` and
defaults to `debian:bookworm-slim`, which keeps a shell available for
operational tooling. A distroless final image
(`gcr.io/distroless/base-debian12:nonroot`) remains available via build-arg.

Vendor Linux packages contain x86_64 binaries, so local builds default to
`linux/amd64`. This is required on ARM64 hosts such as Apple Silicon Macs.

Build the default image:

```bash
docker compose build
```

For a distroless final image:

```bash
docker build \
  --platform linux/amd64 \
  --build-context build-context=./packages \
  --build-arg FLEXNET_PACKAGE_URL="$(sed -n 's/^FLEXNET_PACKAGE_URL=//p' .env)" \
  --build-arg TARGET_TYPE=gcr.io/distroless/base-debian12:nonroot \
  -t flexnetserver:distroless .
```

## Operations

Docker Compose enables `init: true` for the service. This lets Docker run a tiny
init process as PID 1, forward signals, and reap child processes created by
`lmgrd` or vendor daemons without adding an init binary to the image.

Read Docker logs:

```bash
docker compose logs -f flexnet
```

Validate the license service from inside the container:

```bash
docker compose exec flexnet lmutil lmstat -a -c /usr/local/flexlm/licenses/license.dat
```

Apply an updated license file:

```bash
cp /path/to/new_server.lic licenses/latest.lic
chmod 0444 licenses/latest.lic
docker compose restart flexnet
```

Switch vendors: replace the package in `packages/` (or the URL in `.env`),
replace `licenses/latest.lic`, update `FLEXNET_HOSTNAME` /
`FLEXNET_MAC_ADDRESS`, then rebuild:

```bash
docker compose build --no-cache && docker compose up -d
```

## Legal Distribution Guard

Vendor FlexNet binaries (Autodesk NLM, AMD/Xilinx FlexLM, MATLAB) are
redistribution-restricted by their respective license terms. Because this image
embeds vendor binaries after build, redistribution through public registries
such as GHCR is treated as not allowed for this repository.

The default workflow is configured accordingly:

- pull requests, pushes to `main`, monthly scheduled runs, and manual dispatch
  build and smoke-test the local image;
- no workflow step logs in to a registry, pushes an image, signs a remote
  image, or attaches a registry attestation;
- each user or organization must build the image locally, or inside their own
  private CI/CD environment, from the official vendor download;
- packages that require a vendor login are never committed to this repository
  (`packages/` is git-ignored).

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| Container exits immediately | Inspect `docker compose logs flexnet` and verify the license file mount. |
| `xilinxd`/`adskflex` exited with status 45 | The vendor daemon binary is missing from the image — verify `FLEXNET_PACKAGE_URL` points to the complete vendor package (not only `lmgrd`). |
| `Not a valid server hostname` | The container hostname must match the `SERVER` line of the license file (`FLEXNET_HOSTNAME`). |
| `No valid hostids, exiting` | The container MAC address must match the host ID in the license file (`FLEXNET_MAC_ADDRESS`). |
| Health check fails | Run `lmutil lmstat` manually and inspect `docker compose logs flexnet`. |
| Clients cannot obtain licenses | Verify hostname, MAC address, firewall rules and license-file `SERVER` / `VENDOR` lines. |
| Port conflict | Change `FLEXNET_PORT` or stop the conflicting service. |
| Build download fails | Validate `FLEXNET_PACKAGE_URL`; vendor download URLs can change. |

## CI/CD

[`.github/workflows/build.yml`](.github/workflows/build.yml) is intentionally
small. It runs hadolint, builds the image from the public Autodesk NLM URL, and
runs `lmutil lmhostid` as a smoke test. It runs on pull requests, pushes to
`main`, manual dispatch, and once per month as a prophylactic check.

## Migration from pre-2026-10 versions

Environment variables were renamed from `ADM_FLEXNET_*` to `FLEXNET_*`:

| Old | New |
| --- | --- |
| `ADM_FLEXNET_HOSTNAME` | `FLEXNET_HOSTNAME` |
| `ADM_FLEXNET_MAC_ADDRESS` | `FLEXNET_MAC_ADDRESS` |
| `ADM_FLEXNET_NLM_URL` | `FLEXNET_PACKAGE_URL` |
| `ADM_FLEXNET_IMAGE` | `FLEXNET_IMAGE` |
| `ADM_FLEXNET_PLATFORM` | `FLEXNET_PLATFORM` |
| `ADM_FLEXNET_COMMAND` | `FLEXNET_COMMAND` |

The compose service was renamed from `admflexnet` to `flexnet`, the default
published port from `27000` to `2100`, and the `EXPOSE` statements were removed
(port publishing is now handled exclusively by Compose).

## License

This repository's source files are licensed under the [MIT License](LICENSE).
That license does not apply to vendor FlexNet binaries (Autodesk NLM, AMD/Xilinx
FlexLM, MATLAB License Manager) or vendor documentation downloaded during the
Docker build.

Based on the original work by [@haysclark](https://github.com/haysclark).
