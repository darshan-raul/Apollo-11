#!/usr/bin/env bash

set -euo pipefail

CONTEXT="${1:-${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || true)}}"

case "${CONTEXT}" in
  kind-apollo11|kind-apollo11-dev) ;;
  *) printf 'Refusing context %s; Stage 1 only owns kind-apollo11 or kind-apollo11-dev.\n' "${CONTEXT:-<none>}" >&2; exit 2 ;;
esac

kubectl --context "${CONTEXT}" delete namespace apollo-airlines --ignore-not-found --wait=true

if kubectl --context "${CONTEXT}" get namespace apollo-airlines >/dev/null 2>&1; then
  printf 'Stage 1 teardown failed: namespace still exists.\n' >&2
  exit 1
fi

printf 'Stage 1 teardown complete; cluster %s was retained.\n' "${CONTEXT#kind-}"
