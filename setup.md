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
