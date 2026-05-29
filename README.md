# docker-adlmflexnetserver

[![CI](https://github.com/symrex/docker-adlmflexnetserver/actions/workflows/build.yml/badge.svg)](https://github.com/symrex/docker-adlmflexnetserver/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Unofficial container image for running the Autodesk Network License Manager
(NLM) / FlexNet license daemon.

The repository provides a Docker-based deployment pattern for environments that
operate Autodesk network licenses as managed infrastructure. License files stay
outside the image and are mounted read-only at runtime.

This project is not affiliated with Autodesk or Flexera. It does not provide
license entitlements. Before publishing derived images, verify whether your
Autodesk terms allow redistribution of images that contain Autodesk binaries.
Redistribution is treated as not allowed in this repository, so the CI workflow
builds and validates images but does not publish them to GHCR.

## Runtime Contract

| Item | Value |
| --- | --- |
| License daemon | `lmgrd` |
| Default license path | `/opt/flexnetserver/adsk_server.lic` |
| Default log path | `/logs/lmgrd.log` |
| Autodesk vendor port | `2080/tcp` |
| License manager ports | `27000-27009/tcp` |
| Runtime user | `lmadmin` |
| Default Compose command | `-l /logs/lmgrd.log -c /opt/flexnetserver/adsk_server.lic` |
| Compose health check | `lmutil lmstat -a -c /opt/flexnetserver/adsk_server.lic` |

The container hostname and MAC address must match the values used when the
Autodesk license file was generated. If the license file pins different ports,
publish those ports instead of the defaults above.

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
ADM_FLEXNET_HOSTNAME=name_registered_with_autodesk
ADM_FLEXNET_MAC_ADDRESS=XX:XX:XX:XX:XX:XX
ADM_FLEXNET_NLM_URL=https://damassets.autodesk.net/content/dam/autodesk/www/files/linux/nlm11.19.9.0_ipv4_ipv6_linux64.tar.gz
```

Build and start:

```bash
docker compose up --build -d
```

Check status:

```bash
docker compose ps
docker compose logs --tail=100 admflexnet
docker compose exec admflexnet lmutil lmstat -a -c /opt/flexnetserver/adsk_server.lic
```

## Configuration

The Compose file reads runtime values from `.env`.

| Variable | Required | Purpose |
| --- | --- | --- |
| `ADM_FLEXNET_HOSTNAME` | yes | Hostname used by the Autodesk license file. |
| `ADM_FLEXNET_MAC_ADDRESS` | yes | MAC address / host ID registered for the license server. |
| `ADM_FLEXNET_NLM_URL` | yes for builds | Autodesk NLM archive used during image build. |
| `ADM_FLEXNET_IMAGE` | optional | Local image tag used by Docker Compose. |
| `ADM_FLEXNET_PLATFORM` | optional | Build and runtime platform. Defaults to `linux/amd64`, matching Autodesk's Linux NLM archive. |
| `ADM_FLEXNET_COMMAND` | optional | Runtime arguments appended to the image entrypoint. |

Treat license files and `.env` as sensitive operational material.

`ADM_FLEXNET_COMMAND` is passed as the container command. Docker appends it to
the image entrypoint `lmgrd -z -c /opt/flexnetserver/adsk_server.lic`, so the
default runtime invocation is:

```text
lmgrd -z -c /opt/flexnetserver/adsk_server.lic -l /logs/lmgrd.log
```

## Build Targets

The Dockerfile uses a Debian builder stage to download and extract the Autodesk
NLM archive. The final stage is selected with `TARGET_TYPE`; the GitHub Actions
workflow currently builds a distroless final image.

Autodesk's Linux NLM archive contains x86_64 binaries, so local builds default
to `linux/amd64`. This is required on ARM64 hosts such as Apple Silicon Macs.

Build the default image:

```bash
docker build \
  --build-arg NLM_URL="$(sed -n 's/^ADM_FLEXNET_NLM_URL=//p' example.env)" \
  --build-arg TARGET_TYPE=gcr.io/distroless/base-debian12:nonroot \
  -t adlmflexnetserver:local .
```

For local debugging with more runtime tooling, override the final target:

```bash
docker build \
  --build-arg NLM_URL="$(sed -n 's/^ADM_FLEXNET_NLM_URL=//p' example.env)" \
  --build-arg TARGET_TYPE=debian:bookworm-slim \
  -t adlmflexnetserver:debug .
```

## Operations

Docker Compose enables `init: true` for the service. This lets Docker run a tiny
init process as PID 1, forward signals, and reap child processes created by
`lmgrd` or vendor daemons without adding an init binary to the distroless image.

Read Docker logs:

```bash
docker compose logs -f admflexnet
```

Read the persistent debug log:

```bash
tail -f logs/lmgrd.log
```

Validate the license service from inside the container:

```bash
docker compose exec admflexnet lmutil lmstat -a -c /opt/flexnetserver/adsk_server.lic
```

Apply an updated license file:

```bash
cp /path/to/new_adsk_server.lic licenses/latest.lic
chmod 0444 licenses/latest.lic
docker compose restart admflexnet
```

## Security Baseline

- Run with a dedicated license-server hostname and MAC address.
- Mount the Autodesk license file read-only.
- Restrict ports `2080/tcp` and `27000-27009/tcp` to trusted client networks.
- Keep `.env`, license files and logs out of Git.
- Pin an internally built image tag or digest in production instead of relying
  on `latest`.
- Review Autodesk redistribution terms before publishing images.
- Build the image locally or in your own private infrastructure.
- The repository source is MIT licensed; Autodesk/Flexera binaries downloaded
  during the build are not covered by this repository license.

## Legal Distribution Guard

Autodesk's current public
[Terms of Use](https://www.autodesk.com/company/terms-of-use/en/general-terms)
grant use rights within the scope of an Autodesk subscription and prohibit
making Autodesk offerings available to third parties unless expressly
authorized. Because this image embeds Autodesk NLM binaries after build,
redistribution through public registries such as GHCR is treated as not allowed
for this repository.

The default workflow is configured accordingly:

- pull requests, pushes to `main`, monthly scheduled runs, and manual dispatch
  build and smoke-test the local image;
- no workflow step logs in to GHCR, pushes an image, signs a remote image, or
  attaches a registry attestation;
- each user or organization must build the image locally, or inside their own
  private CI/CD environment, from the official Autodesk download.

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| Container exits immediately | Inspect `docker compose logs admflexnet` and verify the license file mount. |
| Health check fails | Run `lmutil lmstat` manually and inspect `logs/lmgrd.log`. |
| Clients cannot obtain licenses | Verify hostname, MAC address, firewall rules and license-file `SERVER` / `VENDOR` lines. |
| Port conflict | Change the host-side published ports or stop the conflicting service. |
| Build download fails | Validate `ADM_FLEXNET_NLM_URL`; Autodesk download URLs can change. |

## CI/CD

[`.github/workflows/build.yml`](.github/workflows/build.yml) is intentionally small. It runs hadolint, builds the distroless image locally, and runs `lmutil lmhostid` as a smoke test. It runs on pull requests, pushes to `main`, manual dispatch, and once per month as a prophylactic check.

No GitHub secrets or repository variables are required.

SBOM generation is not part of the default workflow. If needed, generate it as a separate artifact for a locally built image instead of embedding it into the image:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/syft:latest adlmflexnetserver:local -o cyclonedx-json > sbom.cyclonedx.json
```

Publishing, registry signing and remote SBOM attestation are intentionally not implemented because redistribution of Autodesk binaries is not permitted here.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Changes that alter container behavior should include the exact build command, runtime command and validation output used during testing.

## License

This repository's source files are licensed under the [MIT License](LICENSE). That license does not apply to Autodesk Network License Manager, FlexNet, Autodesk vendor daemon binaries, or Autodesk documentation downloaded during the Docker build.

Based on the original work by [@haysclark](https://github.com/haysclark).
