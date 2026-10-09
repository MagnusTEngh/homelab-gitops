#!/usr/bin/env bash
set -euo pipefail

# Local validation script that mirrors CI checks
# Usage: ./scripts/validate.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "========================================"
echo "Local Validation Script"
echo "========================================"

FAILED=0

# Level 1: Syntax & Format
echo ""
echo "=== YAML Lint ==="
if ! yamllint -c .yamllint.yaml .; then
    echo "FAILED: yamllint failed"
    FAILED=1
fi

# Level 2: Manifest Structure
echo ""
echo "=== Kustomize Build ==="
KUSTOMIZE_PATHS=(
    "./clusters/yggdrasil/flux-system"
    "./infrastructure/cilium"
    "./infrastructure/cert-manager"
    "./infrastructure/gateway-api"
    "./infrastructure/longhorn"
    "./infrastructure/local-path-provisioner"
    "./infrastructure/tailscale"
    "./infrastructure/jottacloud-backup"
    "./apps/gateway-test"
)

for path in "${KUSTOMIZE_PATHS[@]}"; do
    echo "Building: $path"
    if ! kubectl kustomize "$path" > /dev/null 2>&1; then
        echo "FAILED: kustomize build failed for $path"
        FAILED=1
    fi
done

# Level 2: Helm Lint
echo ""
echo "=== Helm Lint ==="
HELM_PATHS=(
    "./infrastructure/cilium"
    "./infrastructure/cert-manager"
)

for path in "${HELM_PATHS[@]}"; do
    echo "Linting: $path"
    if ! helm lint "$path" 2>/dev/null; then
        echo "FAILED: helm lint failed for $path"
        FAILED=1
    fi
done

# Level 2: Schema Validation with kubeconform
echo ""
echo "=== Kubeconform (Strict with Flux and Gateway API CRD schemas) ==="

# Download Flux CRD schemas if not present
FLUX_CRD_URL="https://raw.githubusercontent.com/fluxcd/flux2/main/manifests/crds/bases.yaml"
GATEWAY_API_CRD_URL="https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/gateway-api-crds.yaml"

# Get all kustomize outputs
for path in "${KUSTOMIZE_PATHS[@]}"; do
    echo "Validating: $path"
    kubectl kustomize "$path" | kubeconform -strict -schema-location default -schema-location "https://raw.githubusercontent.com/fluxcd/flux2/{{.Version}}/manifests/crds/" -schema-location "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/{{.Version}}/config/crd/" -skip CustomResourceDefinition,Kustomization,GitRepository,HelmRelease,HelmRepository || FAILED=1
done

# Level 2: Shellcheck
echo ""
echo "=== Shellcheck ==="
SHELL_SCRIPTS=()

# Find shell scripts in talos/
if [ -d "talos" ]; then
    while IFS= read -r -d '' script; do
        SHELL_SCRIPTS+=("$script")
    done < <(find talos/ -name "*.sh" -type f -print0)
fi

# Find shell scripts in scripts/
if [ -d "scripts" ]; then
    while IFS= read -r -d '' script; do
        SHELL_SCRIPTS+=("$script")
    done < <(find scripts/ -name "*.sh" -type f -print0)
fi

if [ ${#SHELL_SCRIPTS[@]} -gt 0 ]; then
    for script in "${SHELL_SCRIPTS[@]}"; do
        echo "Checking: $script"
        if ! shellcheck "$script"; then
            echo "FAILED: shellcheck failed for $script"
            FAILED=1
        fi
    done
else
    echo "No shell scripts found in talos/ or scripts/"
fi

# Level 3: Secret Validation
echo ""
echo "=== Secret Validation (no data/stringData in kind: Secret) ==="

# Check for kind: Secret with data or stringData
SECRET_VIOLATIONS=$(grep -rn "kind: Secret" --include="*.yaml" --include="*.yml" . | while read -r line; do
    file="$(echo "$line" | cut -d: -f1)"
    # Check if the same file has data: or stringData: after kind: Secret
    if grep -A 20 "kind: Secret" "$file" | grep -qE "^\s+(data:|stringData:)"; then
        echo "$file"
    fi
done)

if [ -n "$SECRET_VIOLATIONS" ]; then
    echo "FAILED: Found kind: Secret manifests with data/stringData:"
    echo "$SECRET_VIOLATIONS"
    FAILED=1
else
    echo "No kind: Secret manifests with data/stringData found"
fi

# Level 3: Age Key Pattern Check
echo ""
echo "=== Age Key Pattern Check ==="

# Check for .age files or age-encrypted content references
AGE_VIOLATIONS=$(grep -rnE "(\.age|sops|age\.enc|age-encrypted)" --include="*.yaml" --include="*.yml" . | grep -v "^Binary" | grep -v "image.toolkit.fluxcd.io" | grep -v "# " || true)

if [ -n "$AGE_VIOLATIONS" ]; then
    # Filter out false positives - we're looking for actual age-encrypted secret patterns
    REAL_VIOLATIONS=$(echo "$AGE_VIOLATIONS" | grep -v "image\.toolkit\.fluxcd\.io" | grep -v "# " || true)
    if [ -n "$REAL_VIOLATIONS" ]; then
        echo "FAILED: Found age key patterns:"
        echo "$REAL_VIOLATIONS"
        FAILED=1
    fi
else
    echo "No age key patterns found"
fi

# Level 3: Pluto Deprecation Check
echo ""
echo "=== Pluto Deprecation Check ==="
if command -v pluto &>/dev/null; then
    pluto detect-files -d ./clusters/yggdrasil -o json --ignore-deprecations=false --ignore-removals=false || FAILED=1
else
    echo "pluto not installed, skipping"
fi

echo ""
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo "All validation checks passed!"
    exit 0
else
    echo "Some validation checks FAILED!"
    exit 1
fi
