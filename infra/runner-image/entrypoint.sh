#!/bin/bash
set -euo pipefail

echo "Requesting registration token from ${REGISTRATION_TOKEN_API_URL}..."
REG_TOKEN=$(curl -sS -X POST \
  -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github.v3+json" \
  "${REGISTRATION_TOKEN_API_URL}" | jq -r '.token')

if [ -z "${REG_TOKEN}" ] || [ "${REG_TOKEN}" = "null" ]; then
  echo "ERROR: Failed to obtain a registration token."
  echo "Verify the PAT has admin:org scope and the registration-token URL is correct."
  exit 1
fi

cleanup() {
  echo "Removing runner registration..."
  ./config.sh remove --token "${REG_TOKEN}" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

echo "Configuring runner for ${GH_URL} in group '${RUNNER_GROUP}'..."
./config.sh \
  --url "${GH_URL}" \
  --token "${REG_TOKEN}" \
  --runnergroup "${RUNNER_GROUP}" \
  --labels "${RUNNER_LABELS}" \
  --name "aca-runner-${HOSTNAME}" \
  --unattended \
  --ephemeral \
  --replace

echo "Starting runner (ephemeral, single job)..."
./run.sh
