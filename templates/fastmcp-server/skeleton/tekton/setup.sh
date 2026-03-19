#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:?Usage: $0 <namespace>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Ensuring namespace ${NAMESPACE} exists"
oc get namespace "${NAMESPACE}" &>/dev/null || oc new-project "${NAMESPACE}"

echo "==> Granting image-puller access"
oc policy add-role-to-user system:image-puller system:serviceaccount:"${NAMESPACE}":default \
  -n "${NAMESPACE}" 2>/dev/null || true

echo "==> Applying Tekton pipeline"
oc apply -f "${SCRIPT_DIR}/pipeline.yaml" -n "${NAMESPACE}"

echo "==> Applying Tekton triggers"
oc apply -f "${SCRIPT_DIR}/triggers.yaml" -n "${NAMESPACE}"

echo "==> Waiting for EventListener to become ready"
for i in $(seq 1 30); do
  EL_ROUTE=$(oc get route -n "${NAMESPACE}" -l eventlistener="${NAMESPACE}"-*-listener \
    -o jsonpath='{.items[0].spec.host}' 2>/dev/null) && break
  sleep 5
done

if oc get eventlistener -n "${NAMESPACE}" -o name &>/dev/null; then
  echo "==> Creating Route for EventListener"
  EL_SVC=$(oc get svc -n "${NAMESPACE}" -l "app.kubernetes.io/managed-by=EventListener" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [ -n "${EL_SVC}" ]; then
    oc expose svc "${EL_SVC}" -n "${NAMESPACE}" 2>/dev/null || true
    EL_ROUTE=$(oc get route "${EL_SVC}" -n "${NAMESPACE}" \
      -o jsonpath='{.spec.host}' 2>/dev/null || true)
  fi
fi

echo ""
echo "===== Setup Complete ====="
echo ""
echo "To run the pipeline manually:"
echo "  oc create -f ${SCRIPT_DIR}/pipelinerun.yaml"
echo ""
if [ -n "${EL_ROUTE:-}" ]; then
  echo "To configure GitHub webhook for automatic triggers:"
  echo "  Payload URL: http://${EL_ROUTE}"
  echo "  Content type: application/json"
  echo "  Events: Just the push event"
else
  echo "EventListener route not found yet. Run the following to get it later:"
  echo "  oc get route -n ${NAMESPACE} -l app.kubernetes.io/managed-by=EventListener"
fi
