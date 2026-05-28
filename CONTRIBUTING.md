# Contributing

This guide is intended for project contributors.

**Working on your first Pull Request?** You can learn how from this *free* series [How to Contribute to an Open Source Project on GitHub](https://kcd.im/pull-request)

## Code of Conduct

Please make sure you're familiar with and follow the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

- [Docker](https://www.docker.com/get-started/) (latest stable version)
- [Docker Compose](https://docs.docker.com/compose/) (v2.x)
- [Git](https://git-scm.com/)

### Development Setup

1. Fork and clone the repository:
```bash
git clone https://github.com/symrex/docker-adlmflexnetserver.git
cd docker-adlmflexnetserver
```

2. Copy and configure the environment file:
```bash
cp example.env .env
# Edit .env with your values
```

3. Build and start the container:
```bash
docker compose up -d --build
```

4. Verify the server is running:
```bash
docker exec -it <container-id> /bin/bash
lmutil lmstat -a -c /opt/flexnetserver/adsk_server.lic
```

## Development Workflow

### Branch Naming Convention

Use descriptive branch names:
- `feature/<description>` – New features
- `fix/<description>` – Bug fixes
- `docs/<description>` – Documentation changes
- `chore/<description>` – Maintenance tasks

### Building and Testing

**Build the image:**
```bash
docker compose build
# or
docker build -t adlmflexnetserver .
```

**Run with Docker Compose:**
```bash
docker compose up -d
```

**Check logs:**
```bash
docker compose logs -f
# or
docker logs -f <container-id>
```

**Lint the Dockerfile:**
```bash
hadolint Dockerfile
```

### Commit Message Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat:` – A new feature
- `fix:` – A bug fix
- `docs:` – Documentation only changes
- `style:` – Changes that do not affect the meaning of the code
- `refactor:` – A code change that neither fixes a bug nor adds a feature
- `test:` – Adding or updating tests
- `chore:` – Changes to the build process or auxiliary tools

**Examples:**
```
feat(dockerfile): add IPv6 support for fedora base image
fix(compose): correct volume mount path for license files
docs: update troubleshooting section with common issues
```

## Reviewing Pull Requests

1. Ensure you have locally built and tested the Docker container.
2. Verify all ports (2080, 27000-27009) are correctly exposed.
3. Confirm the license file mount path is correct (`/opt/flexnetserver/adsk_server.lic`).
4. Check that the container runs under the `lmadmin` user.

## Approving Pull Requests

1. Ensure there are no common Dockerfile pitfalls by _linting_ with [hadolint](https://github.com/hadolint/hadolint).
```bash
hadolint Dockerfile
```

2. Ensure the merge message follows a clear and descriptive format.

3. Use an appropriate merge strategy. This keeps a clean history in `main`, with a full history available in Pull Requests.

## Releasing

A [GitHub Actions](https://github.com/features/actions) workflow is triggered when code is pushed or merged to `main`. The workflow will:

1. Build and test the Docker image
2. Publish the Docker image to [GHCR](https://github.com/symrex/docker-adlmflexnetserver/pkgs/container/docker-adlmflexnetserver) with the `latest` tag

## Reporting Issues

### Bug Reports

When reporting a bug, please include:

- **Container version** – Output of `docker images`
- **Docker version** – Output of `docker --version`
- **Host OS** – Your operating system and version
- **Steps to reproduce** – Clear, numbered steps
- **Expected behavior** – What you expected to happen
- **Actual behavior** – What actually happened
- **Logs** – Relevant log output from `docker logs`

### Feature Requests

Please describe:

- The problem the feature solves
- How it should work
- Any relevant examples or use cases

## Security

- Do not commit license files or any sensitive data
- Do not expose secrets in environment variables without encryption
- Report security vulnerabilities privately to the maintainers

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
