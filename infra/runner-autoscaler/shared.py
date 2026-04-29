import json
import logging
import os
import urllib.error
import urllib.request

from azure.identity import ManagedIdentityCredential


ARM_API_VERSION = "2024-11-01"
GITHUB_API_VERSION = "2022-11-28"

# Log that the module loaded so we can confirm a successful import in App Insights.
logging.info("shared module loaded (azure-identity available)")


# ---------------------------------------------------------------------------
# Environment helpers
# ---------------------------------------------------------------------------

def get_env(name: str, default: str = "") -> str:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


def _mask(value: str) -> str:
    """Return a masked representation safe to log (first 4 chars + …)."""
    if not value:
        return "(empty)"
    if value.startswith("@Microsoft.KeyVault"):
        return "(Key Vault reference — not yet resolved)"
    return value[:4] + "…"


def get_runner_label() -> str:
    return get_env("RUNNER_LABEL")


def get_max_runners() -> int:
    return int(get_env("MAX_RUNNERS", "10"))


def get_vmss_resource_id() -> str:
    return get_env("VMSS_RESOURCE_ID")


def get_github_pat() -> str:
    return get_env("GITHUB_PAT")


def get_github_org() -> str:
    return get_env("GITHUB_ORG")


def get_webhook_secret() -> str:
    return get_env("GITHUB_WEBHOOK_SECRET")


def get_target_repositories() -> set[str]:
    repositories = get_env("TARGET_REPOSITORIES")
    if not repositories:
        return set()
    return {item.strip().lower() for item in repositories.split(",") if item.strip()}


def log_env_summary() -> None:
    """Log the resolved (masked) values of every required env var."""
    logging.info(
        "Env: GITHUB_ORG=%s RUNNER_LABEL=%s MAX_RUNNERS=%s "
        "VMSS_RESOURCE_ID=%s TARGET_REPOSITORIES=%s "
        "GITHUB_PAT=%s GITHUB_WEBHOOK_SECRET=%s",
        get_github_org() or "(empty)",
        get_runner_label() or "(empty)",
        get_env("MAX_RUNNERS", "10"),
        get_vmss_resource_id() or "(empty)",
        get_env("TARGET_REPOSITORIES") or "(empty)",
        _mask(get_github_pat()),
        _mask(get_webhook_secret()),
    )


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

def _read_error_body(exc: urllib.error.HTTPError) -> str:
    """Extract and truncate the response body from an HTTPError."""
    try:
        return exc.read().decode("utf-8", errors="replace")[:2000]
    except Exception as read_exc:
        return f"(could not read response body: {read_exc})"


# ---------------------------------------------------------------------------
# Azure Resource Manager
# ---------------------------------------------------------------------------

def build_management_headers() -> dict[str, str]:
    logging.info("Acquiring Azure managed-identity token for management.azure.com …")
    try:
        token = ManagedIdentityCredential().get_token("https://management.azure.com/.default").token
    except Exception as exc:
        logging.error(
            "Failed to acquire ARM token via ManagedIdentityCredential. "
            "Ensure the Function App has a system-assigned identity and that "
            "the identity has been granted the required RBAC role on the VMSS. "
            "Error: %s",
            exc,
            exc_info=True,
        )
        raise
    logging.info("ARM token acquired successfully.")
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def get_vmss_model() -> dict:
    resource_id = get_vmss_resource_id()
    if not resource_id:
        logging.error(
            "VMSS_RESOURCE_ID is empty. "
            "Check that the app setting is set correctly in the Function App configuration."
        )
        raise ValueError("VMSS_RESOURCE_ID is not configured")

    url = f"https://management.azure.com{resource_id}?api-version={ARM_API_VERSION}"
    logging.info("GET VMSS model: %s", url)
    try:
        request = urllib.request.Request(url, headers=build_management_headers())
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = _read_error_body(exc)
        logging.error(
            "ARM GET VMSS model failed. HTTP %d %s\nURL: %s\nResponse body: %s",
            exc.code, exc.reason, url, body,
            exc_info=True,
        )
        raise
    except urllib.error.URLError as exc:
        logging.error("Network error reaching ARM for VMSS model. URL: %s  Reason: %s", url, exc.reason, exc_info=True)
        raise

    sku = data.get("sku", {})
    logging.info(
        "VMSS model retrieved: name=%s sku=%s capacity=%s provisioningState=%s",
        data.get("name"),
        sku.get("name"),
        sku.get("capacity"),
        data.get("properties", {}).get("provisioningState"),
    )
    return data


def get_current_capacity() -> int:
    model = get_vmss_model()
    return int(model.get("sku", {}).get("capacity", 0))


def get_vmss_instance_states() -> dict[str, int]:
    """Return a breakdown of actual VMSS instance counts by provisioning state.

    Keys: 'total', 'creating', 'succeeded', 'failed', 'other'.
    Used to detect in-flight bootstrapping instances that have not yet registered
    as GitHub runners.
    """
    resource_id = get_vmss_resource_id()
    url = f"https://management.azure.com{resource_id}/virtualMachines?api-version={ARM_API_VERSION}"
    logging.info("GET VMSS instance list: %s", url)
    try:
        request = urllib.request.Request(url, headers=build_management_headers())
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = _read_error_body(exc)
        logging.error(
            "ARM GET VMSS instances failed. HTTP %d %s\nURL: %s\nResponse body: %s",
            exc.code, exc.reason, url, body,
            exc_info=True,
        )
        raise
    except urllib.error.URLError as exc:
        logging.error("Network error reaching ARM for VMSS instances. URL: %s  Reason: %s", url, exc.reason, exc_info=True)
        raise

    counts: dict[str, int] = {"total": 0, "creating": 0, "succeeded": 0, "failed": 0, "other": 0}
    for vm in data.get("value", []):
        state = (vm.get("properties", {}).get("provisioningState") or "").lower()
        counts["total"] += 1
        if state == "creating":
            counts["creating"] += 1
        elif state == "succeeded":
            counts["succeeded"] += 1
        elif state == "failed":
            counts["failed"] += 1
            logging.warning(
                "VMSS instance %s is in Failed state: %s",
                vm.get("instanceId"),
                vm.get("properties", {}).get("statusMessage", "(no status message)"),
            )
        else:
            counts["other"] += 1
            logging.info("VMSS instance %s has unexpected state '%s'", vm.get("instanceId"), state)

    logging.info("VMSS instance states: %s", counts)
    return counts


def set_capacity(desired_capacity: int) -> int:
    """Set the VMSS capacity to *desired_capacity*.

    Fetches the current model to obtain the SKU name and tier so the PATCH
    includes a complete SKU object (prevents ARM from nulling out those fields).
    Returns the new capacity after the update (or the unchanged capacity if no
    PATCH was needed).
    """
    model = get_vmss_model()
    sku = model.get("sku", {})
    current_capacity = int(sku.get("capacity", 0))

    if current_capacity == desired_capacity:
        logging.info("set_capacity: already at desired capacity %d — skipping PATCH", desired_capacity)
        return current_capacity

    patch_body = {
        "sku": {
            "name": sku.get("name"),
            "tier": sku.get("tier", "Standard"),
            "capacity": desired_capacity,
        }
    }
    payload = json.dumps(patch_body).encode("utf-8")
    url = f"https://management.azure.com{get_vmss_resource_id()}?api-version={ARM_API_VERSION}"
    logging.info(
        "PATCH VMSS capacity: %d -> %d  sku=%s  url=%s",
        current_capacity, desired_capacity, sku.get("name"), url,
    )
    try:
        request = urllib.request.Request(url, data=payload, headers=build_management_headers(), method="PATCH")
        with urllib.request.urlopen(request, timeout=60) as response:
            response_code = response.getcode()
    except urllib.error.HTTPError as exc:
        body = _read_error_body(exc)
        logging.error(
            "ARM PATCH VMSS capacity failed. HTTP %d %s\n"
            "Requested capacity: %d -> %d  sku=%s\n"
            "URL: %s\n"
            "Response body: %s",
            exc.code, exc.reason,
            current_capacity, desired_capacity, sku.get("name"),
            url, body,
            exc_info=True,
        )
        raise
    except urllib.error.URLError as exc:
        logging.error(
            "Network error during ARM PATCH VMSS capacity. URL: %s  Reason: %s",
            url, exc.reason, exc_info=True,
        )
        raise

    logging.info(
        "VMSS capacity PATCH accepted (HTTP %d): %d -> %d (sku=%s)",
        response_code, current_capacity, desired_capacity, sku.get("name"),
    )
    return desired_capacity


# ---------------------------------------------------------------------------
# GitHub API
# ---------------------------------------------------------------------------

def github_request(url: str) -> dict:
    pat = get_github_pat()
    if not pat or pat.startswith("@Microsoft.KeyVault"):
        logging.error(
            "GITHUB_PAT is not resolved. Current value: %s  "
            "Ensure the Key Vault secret 'github-actions-pat' exists and the "
            "Function App identity has 'Key Vault Secrets User' on the vault.",
            _mask(pat),
        )
        raise ValueError(f"GITHUB_PAT is not configured (value: {_mask(pat)})")

    logging.info("GitHub API GET: %s", url)
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {pat}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
            "User-Agent": "hexmaster-runner-autoscaler",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = _read_error_body(exc)
        logging.error(
            "GitHub API request failed. HTTP %d %s\n"
            "URL: %s\n"
            "Response body: %s\n"
            "Hint: HTTP 401 means the PAT is invalid or expired. "
            "HTTP 403 may indicate insufficient PAT scopes (needs 'manage_runners:org').",
            exc.code, exc.reason, url, body,
            exc_info=True,
        )
        raise
    except urllib.error.URLError as exc:
        logging.error("Network error reaching GitHub API. URL: %s  Reason: %s", url, exc.reason, exc_info=True)
        raise


def list_runners() -> tuple[int, int]:
    """Return (total_registered, busy_count) for runners carrying the target label.

    A single GitHub API scan is shared by callers that need both values.
    """
    org = get_github_org()
    label = get_runner_label()

    if not org:
        logging.error("GITHUB_ORG is empty — cannot list runners.")
        raise ValueError("GITHUB_ORG is not configured")
    if not label:
        logging.error("RUNNER_LABEL is empty — cannot filter runners.")
        raise ValueError("RUNNER_LABEL is not configured")

    logging.info("Listing runners for org=%s label=%s …", org, label)
    page = 1
    total = 0
    busy = 0

    while True:
        url = f"https://api.github.com/orgs/{org}/actions/runners?per_page=100&page={page}"
        payload = github_request(url)
        runners = payload.get("runners", [])
        if not runners:
            break

        for runner in runners:
            runner_labels = {item.get("name") for item in runner.get("labels", [])}
            if label in runner_labels:
                total += 1
                is_busy = runner.get("busy", False)
                if is_busy:
                    busy += 1
                logging.info(
                    "Runner found: id=%s name=%s status=%s busy=%s labels=%s",
                    runner.get("id"),
                    runner.get("name"),
                    runner.get("status"),
                    is_busy,
                    sorted(runner_labels),
                )

        if len(runners) < 100:
            break

        page += 1

    logging.info("Runner scan complete: total=%d busy=%d (label=%s org=%s)", total, busy, label, org)
    return total, busy


def list_busy_runners() -> int:
    """Return the number of busy runners with the target label (convenience wrapper)."""
    _, busy = list_runners()
    return busy


# ---------------------------------------------------------------------------
# Webhook helpers
# ---------------------------------------------------------------------------

def is_target_job(body: dict) -> bool:
    workflow_job = body.get("workflow_job", {})
    labels = {item.lower() for item in workflow_job.get("labels", [])}
    repository = body.get("repository", {}).get("full_name", "").lower()
    runner_label = get_runner_label().lower()
    target_repositories = get_target_repositories()

    if runner_label not in labels:
        logging.info(
            "Job ignored: runner label '%s' not in job labels %s (job_id=%s repo=%s)",
            runner_label, sorted(labels), workflow_job.get("id"), repository,
        )
        return False

    if target_repositories and repository not in target_repositories:
        logging.info(
            "Job ignored: repository '%s' not in target list %s (job_id=%s)",
            repository, sorted(target_repositories), workflow_job.get("id"),
        )
        return False

    return True


def json_response(body: dict) -> str:
    return json.dumps(body, indent=2)
