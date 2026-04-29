import json
import logging
import os
import urllib.request

from azure.identity import ManagedIdentityCredential


ARM_API_VERSION = "2024-11-01"
GITHUB_API_VERSION = "2022-11-28"


def get_env(name: str, default: str = "") -> str:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


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


def build_management_headers() -> dict[str, str]:
    token = ManagedIdentityCredential().get_token("https://management.azure.com/.default").token
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def github_request(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {get_github_pat()}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
            "User-Agent": "hexmaster-runner-autoscaler",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def list_runners() -> tuple[int, int]:
    """Return (total_registered, busy_count) for runners carrying the target label.

    A single GitHub API scan is shared by callers that need both values.
    """
    org = get_github_org()
    label = get_runner_label()
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
            labels = {item.get("name") for item in runner.get("labels", [])}
            if label in labels:
                total += 1
                if runner.get("busy"):
                    busy += 1

        if len(runners) < 100:
            break

        page += 1

    return total, busy


def list_busy_runners() -> int:
    """Return the number of busy runners with the target label (convenience wrapper)."""
    _, busy = list_runners()
    return busy


def get_vmss_model() -> dict:
    resource_id = get_vmss_resource_id()
    request = urllib.request.Request(
        f"https://management.azure.com{resource_id}?api-version={ARM_API_VERSION}",
        headers=build_management_headers(),
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


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
    request = urllib.request.Request(
        f"https://management.azure.com{resource_id}/virtualMachines?api-version={ARM_API_VERSION}",
        headers=build_management_headers(),
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.loads(response.read().decode("utf-8"))

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
        else:
            counts["other"] += 1

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
        return current_capacity

    payload = json.dumps(
        {
            "sku": {
                "name": sku.get("name"),
                "tier": sku.get("tier", "Standard"),
                "capacity": desired_capacity,
            }
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        f"https://management.azure.com{get_vmss_resource_id()}?api-version={ARM_API_VERSION}",
        data=payload,
        headers=build_management_headers(),
        method="PATCH",
    )
    with urllib.request.urlopen(request, timeout=60):
        pass

    logging.info("VMSS capacity PATCH: %d -> %d (sku=%s)", current_capacity, desired_capacity, sku.get("name"))
    return desired_capacity


def is_target_job(body: dict) -> bool:
    workflow_job = body.get("workflow_job", {})
    labels = {item.lower() for item in workflow_job.get("labels", [])}
    repository = body.get("repository", {}).get("full_name", "").lower()

    if get_runner_label().lower() not in labels:
        return False

    target_repositories = get_target_repositories()
    if target_repositories and repository not in target_repositories:
        return False

    return True


def json_response(body: dict) -> str:
    return json.dumps(body, indent=2)
