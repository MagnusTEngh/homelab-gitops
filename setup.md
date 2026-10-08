# Setup

## Nix Development Environment

This repository uses a Nix flake to provide a reproducible development environment with all tools needed for working on the cluster, validating configurations, and verifying functionality.

### Prerequisites

- Nix installed with flakes enabled
- direnv installed (optional, recommended)

### Quick Start

#### Option 1: Manual activation

```bash
nix develop
```

#### optionally activate

direnv allow

### Environment Variables

The dev shell sets:

- SECRETS_REPO: defaults to ../homelab-secrets
  - Override it per session if needed: SECRETS_REPO=/path/to/secrets nix develop
- SOPS_AGE_KEY_FILE: set automatically only if ~/.config/sops/age/keys.txt exists



