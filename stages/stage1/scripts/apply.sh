#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTEXT="${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || true)}"
SKIP_BUILD=false

usage() {
  printf 'Usage: %s [--skip-build] [--context kind-apollo11|kind-apollo11-dev]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true; shift ;;
    --context) CONTEXT="${2:-}"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "${CONTEXT}" in
  kind-apollo11|kind-apollo11-dev) ;;
  *) printf 'Refusing context %s; Stage 1 only owns kind-apollo11 or kind-apollo11-dev.\n' "${CONTEXT:-<none>}" >&2; exit 2 ;;
esac

kube() {
  kubectl --context "${CONTEXT}" "$@"
}

kube cluster-info >/dev/null

if [[ "${SKIP_BUILD}" == false ]]; then
  cluster_name="${CONTEXT#kind-}"
  "${SCRIPT_DIR}/build-images.sh" --cluster "${cluster_name}"
fi

printf '\n[1/6] Applying namespace, configuration, Secret, and ServiceAccounts\n'
kube apply -f "${STAGE_DIR}/k8s/config/namespace.yaml"
kube apply -f "${STAGE_DIR}/k8s/config/configmap.yaml"
kube apply -f "${STAGE_DIR}/k8s/config/secrets.yaml"
kube apply -f "${STAGE_DIR}/k8s/config/serviceaccounts.yaml"

printf '\n[2/6] Applying database and Redis Deployments and Services\n'
for component in identity-db flight-db booking-db redis; do
  kube apply -f "${STAGE_DIR}/k8s/infra/${component}/${component}-dep.yaml"
  kube apply -f "${STAGE_DIR}/k8s/infra/${component}/${component}-svc.yaml"
done

printf '\n[3/6] Waiting for infrastructure Deployments\n'
for deployment in identity-db flight-db booking-db redis; do
  kube rollout status "deployment/${deployment}" -n apollo-airlines --timeout=180s
done

printf '\n[4/6] Applying strict, repeatable database initialization Jobs\n'
kube apply -f "${STAGE_DIR}/k8s/jobs/identity-init-configmap.yaml"
kube apply -f "${STAGE_DIR}/k8s/jobs/flight-init-configmap.yaml"
kube apply -f "${STAGE_DIR}/k8s/jobs/booking-init-configmap.yaml"
kube delete jobs -n apollo-airlines \
  init-identity-db init-flight-db init-booking-db \
  --ignore-not-found --wait=true
kube apply -f "${STAGE_DIR}/k8s/jobs/init-identity-db.yaml"
kube apply -f "${STAGE_DIR}/k8s/jobs/init-flight-db.yaml"
kube apply -f "${STAGE_DIR}/k8s/jobs/init-booking-db.yaml"
for job in init-identity-db init-flight-db init-booking-db; do
  kube wait --for=condition=Complete "job/${job}" -n apollo-airlines --timeout=180s
done

printf '\n[5/6] Applying the six application Deployments and Services\n'
for component in identity flight booking search notification frontend; do
  kube apply -f "${STAGE_DIR}/k8s/apps/${component}/${component}-dep.yaml"
  kube apply -f "${STAGE_DIR}/k8s/apps/${component}/${component}-svc.yaml"
done

printf '\n[6/6] Waiting for application rollouts\n'
for deployment in identity flight booking search notification frontend; do
  kube rollout status "deployment/${deployment}" -n apollo-airlines --timeout=180s
done

printf '\nStage 1 is applied. Run:\n  bash %s/verify.sh %s\n' "${SCRIPT_DIR}" "${CONTEXT}"
