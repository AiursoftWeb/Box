# Box

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://gitlab.aiursoft.com/aiursoft/box/-/blob/master/LICENSE)
[![ManHours](https://manhours.aiursoft.com/r/gitlab.aiursoft.com/aiursoft/box.svg)](https://gitlab.aiursoft.com/aiursoft/box/-/commits/master?ref_type=heads)
[![Website](https://img.shields.io/website?url=https%3A%2F%2Fwww.aiursoft.com%2F)](https://www.aiursoft.com)

Box is a modular and secure single-node datacenter bootstrap system designed for home labs, edge servers, and self-hosting environments. It automates the initialization of essential infrastructure services in a staged and dependency-aware manner.

## Why Box?

Traditional container orchestration systems often assume a fully operational infrastructure from the start. However, in many self-hosted or offline environments, especially bare-metal deployments, this assumption fails. **Box provides a deterministic, local-first bootstrapping flow**, gradually assembling the necessary layers for a secure and feature-complete datacenter.

### Key Features

- Stage-based initialization of critical services
- Secure container registry bootstrap without relying on the public internet
- OIDC-based access control via Authentik and Zot
- Built-in mirroring of essential images
- IP-layer access control for internal registries
- Clear separation of concerns per layer (network, web, auth, app)
- Resilient against CI misuse or unauthorized image pushes

---

## System Overview

```mermaid
flowchart TD
    A[Stage 0: Internal Bootstrap Registry] --> B[Stage 1: Pull Public Images]
    B --> C[Stage 2: Basic Web Infrastructure]
    C --> D[Stage 3: Authentik + Zot with OIDC]
    D --> E[Stage 4: Business Applications]

    subgraph Bootstrap Flow
        A -->|pull-through| B
        B -->|internal| C
        C -->|authenticated| D
        D -->|token-gated| E
    end
````

---

## Stage-by-Stage Breakdown

### Stage 0: Internal Bootstrap Registry

Starts a minimal local Docker registry (`localhost:8080`) with no authentication, protected by firewall rules. This registry acts as the root of trust for all subsequent image loading operations.

* Does not expose to the external network
* Serves only `127.0.0.1`
* Prevents unauthorized CI/CD image pushes

### Stage 1: Image Mirroring

Mirrors key public images (e.g. `ubuntu`, `caddy`, `authentik`, `postgres`, `redis`) into the internal registry to eliminate external dependencies.

* Uses local Docker pull/tag/push cycle
* Optionally includes GPU drivers and builder images
* Ensures base images are reproducible and cached

### Stage 2: Basic Web Infrastructure

Builds and deploys essential HTTP-layer services such as:

* Reverse proxy (Caddy)
* FRP tunnel client
* Static config distribution

These services enable ingress and routing for the Authentik identity provider and future applications.

### Stage 3: Authentik and Zot

Bootstraps a full OIDC-based registry authentication system:

* **Authentik** for unified identity management
* **Zot** as a secure, authenticated OCI registry
* Integrates via OAuth2/OIDC
* Uses Postgres and Redis as dependencies

Zot replaces the Stage 0 registry, offering access control and audit logs.

### Stage 4: Business Services

With a functional infrastructure and secure registry in place, application containers are deployed:

* GitLab, Nextcloud, Gitea, Jellyfin, etc.
* Only pushable via authorized CI pipelines
* Application secrets injected via Docker Swarm secrets

---

## Registry Access Model

```mermaid
sequenceDiagram
    participant Dev
    participant Runner
    participant Registry
    participant Authentik

    Dev->>Runner: Git push triggers pipeline
    Runner->>Authentik: OIDC Token Exchange
    Authentik-->>Runner: Access Token
    Runner->>Registry: docker login with token
    Runner->>Registry: docker push myapp:tag
    Registry-->>Runner: 200 OK (if authorized)
```

* CI/CD pipelines require OIDC token to push images
* Unauthorized users or compromised runners cannot push to either registry
* Public pull access can be fine-tuned with anonymous policy

---

## Why Is Box Unique?

* **Self-contained**: No dependency on cloud-native control planes
* **Deterministic**: Starts from zero, always in a predictable order
* **Security-first**: Push control via firewall + OIDC tokens
* **Offline-friendly**: Caches critical images during bootstrap
* **Extensible**: Add new stacks at any stage without interfering with the boot logic

---

## Project Structure

```bash
Box/
├── stage0/           # Bootstrap Registry
├── stage1/           # Image Mirroring Scripts
├── stage2/           # Basic Web Layer (Caddy, FRP)
├── stage3/           # Authentik + Zot Auth Stack
├── stage4/           # Business Applications
├── deploy.sh         # Main Orchestrator Script
└── README.md         # This file
```

---

## Getting Started

To use Box, run:

```bash
sudo bash deploy.sh
```

This will automatically:

1. Install dependencies
2. Initialize Docker Swarm
3. Build and deploy all stages incrementally
4. Lock down internal registries with firewall
5. Wait for each system to be ready before continuing

---

## Final Notes

Box is designed for technical users who value reproducibility, security, and local-first deployments. It makes no assumptions about the availability of external infrastructure and provides a clean, transparent bootstrap flow for your datacenter.
