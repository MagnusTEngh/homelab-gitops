#!/usr/bin/env bash

# Validation shared by CI, pre-commit and the nix devShell.

# Usage: scripts/validate.sh [check ...]

#   checks: yaml build schema secrets age shell pluto   (default: all)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ALL_CHECKS=(yaml build schema secrets age shell pluto)
MANIFEST_ROOTS=(clusters infrastructure apps)

# Talos v1.13.7 runs Kubernetes v1.30.4
K8S_VERSION="${K8S_VERSION:-1.30.4}"
CRD_CATALOG='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

# Additional schema locations for CRDs not in datreeio catalog
CILIUM_SCHEMA='https://raw.githubusercontent.com/cilium/cilium/v2.0.0/install/kubernetes/cilium/crds'
TAILSCALE_SCHEMA='https://raw.githubusercontent.com/tailscale/tailscale-operator/main/config/crd'
GATEWAY_API_SCHEMA='https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.0.0/config/crd'

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

BUILT=0
FAILED=0

log() { printf '\n=== %s ===\n' "$*"; }

fail() {
  printf '%s\n' "$*" >&2
  FAILED=1
}

need() {
  local tool
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      fail "missing tool: $tool"
      return 1
    fi
  done
}

# Directories with a kustomization.yaml that build standalone.
kustomize_dirs() {
  local f
  while IFS= read -r -d '' f; do
    grep -qE '^kind:[[:space:]]*Component' "$f" && continue
    dirname "$f"
  done < <(find "${MANIFEST_ROOTS[@]}" -name kustomization.yaml -type f -print0 | sort -z)
}

# Build every kustomize dir once into $BUILD_DIR; later checks reuse the output.
ensure_built() {
  [ "$BUILT" -eq 1 ] && return 0
  BUILT=1
  need kubectl || return 0

  local dir out
  while IFS= read -r dir; do
    out="$BUILD_DIR/${dir//\//__}.yaml"
    if ! kubectl kustomize "$dir" >"$out" 2>"$out.err"; then
      fail "kustomize build: $dir"
      sed 's/^/  /' "$out.err" >&2
      rm -f "$out"
    fi
  done < <(kustomize_dirs)
}

check_yaml() {
  log "yamllint"
  need yamllint || return 0
  yamllint -c .yamllint.yaml . || fail "yamllint"
}

check_build() {
  log "kustomize build"
  ensure_built
  echo "built $(find "$BUILD_DIR" -name '*.yaml' -type f | wc -l | tr -d ' ') kustomizations"
}

check_schema() {
  log "kubeconform"
  need kubeconform || return 0
  ensure_built

  local file
  while IFS= read -r -d '' file; do
    kubeconform -strict -summary \
      -kubernetes-version "$K8S_VERSION" \
      -schema-location default \
      -schema-location "$CRD_CATALOG" \
      -schema-location "$CILIUM_SCHEMA" \
      -schema-location "$TAILSCALE_SCHEMA" \
      -schema-location "$GATEWAY_API_SCHEMA" \
      "$file" || fail "kubeconform: $file"
  done < <(find "$BUILD_DIR" -name '*.yaml' -type f -print0)
}

check_secrets() {
  log "No Secret with data/stringData"
  need yq || return 0
  ensure_built

  local files=() f hits
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <({
    git ls-files -z -- '*.yaml' '*.yml'
    find "$BUILD_DIR" -name '*.yaml' -type f -print0
  })

  for f in "${files[@]}"; do
    hits="$(yq eval-all \
      'select(.kind == "Secret" and (.data != null or .stringData != null)) | .metadata.name' \
      "$f")" || {
      fail "yq could not parse $f"
      continue
    }
    if [ -n "$hits" ]; then
      printf 'FAIL: Secret with data/stringData in %s: %s\n' "$f" "$hits" >&2
      FAILED=1
    fi
  done
}

check_age() {
  log "No key material in repo"
  local hits

  hits="$(git grep -nEI \
    -e 'AGE-SECRET-KEY-1[A-Z0-9]{58}' \
    -e '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' || true)"
  if [ -n "$hits" ]; then
    printf 'FAIL: key material found:\n%s\n' "$hits" >&2
    FAILED=1
  fi

  hits="$(git ls-files | grep -Ei '(^|/)(talosconfig|kubeconfig|secrets\.ya?ml|keys\.txt)$|\.(age|agekey)$' || true)"
  if [ -n "$hits" ]; then
    printf 'FAIL: secret-looking files tracked:\n%s\n' "$hits" >&2
    FAILED=1
  fi
}

check_shell() {
  log "shellcheck"
  need shellcheck || return 0
  git ls-files -z '*.sh' | xargs -0 -r shellcheck || fail "shellcheck"
}

check_pluto() {
  log "pluto (deprecated/removed APIs)"
  need pluto || return 0
  ensure_built

  pluto detect-files -d "$BUILD_DIR" -o wide \
    --target-versions "k8s=v${K8S_VERSION}" || fail "pluto"
}

main() {
  local checks=("$@") c

  if [ "${#checks[@]}" -eq 0 ] || [ "${checks[0]}" = "all" ]; then
    checks=("${ALL_CHECKS[@]}")
  fi

  for c in "${checks[@]}"; do
    case "$c" in
      yaml | build | schema | secrets | age | shell | pluto) "check_$c" ;;
      *)
        echo "unknown check: $c (valid: ${ALL_CHECKS[*]} all)" >&2
        exit 2
        ;;
    esac
  done

  if [ "$FAILED" -ne 0 ]; then
    echo >&2
    echo "Validation FAILED" >&2
    exit 1
  fi

  echo
  echo "Validation passed"
}

main "$@"
