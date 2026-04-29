import hashlib
import hmac
import logging

import azure.functions as func

from shared import (
    get_current_capacity,
    get_max_runners,
    get_runner_label,
    get_vmss_instance_states,
    get_webhook_secret,
    is_target_job,
    json_response,
    list_runners,
    set_capacity,
)


def _is_valid_signature(body: bytes, signature_header: str) -> bool:
    secret = get_webhook_secret().encode("utf-8")
    expected = "sha256=" + hmac.new(secret, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature_header or "")


def main(req: func.HttpRequest) -> func.HttpResponse:
    body = req.get_body()
    signature = req.headers.get("X-Hub-Signature-256", "")
    event_name = req.headers.get("X-GitHub-Event", "")

    if event_name != "workflow_job":
        return func.HttpResponse(json_response({"message": "ignored", "reason": "event_not_supported"}), status_code=202, mimetype="application/json")

    if not _is_valid_signature(body, signature):
        return func.HttpResponse(json_response({"message": "invalid signature"}), status_code=401, mimetype="application/json")

    payload = req.get_json()
    if not is_target_job(payload):
        return func.HttpResponse(json_response({"message": "ignored", "reason": "runner_pool_mismatch"}), status_code=202, mimetype="application/json")

    action = payload.get("action")

    try:
        current_capacity = get_current_capacity()
        registered_runners, busy_runners = list_runners()
        desired_capacity = current_capacity

        if action == "queued":
            desired_capacity = min(max(current_capacity, busy_runners) + 1, get_max_runners())

        elif action == "completed" and busy_runners == 0:
            # Guard against cancelling in-flight VM bootstrapping.
            # When a VM is provisioning (cloud-init + runner startup takes 3-5 min) it
            # won't have registered as a GitHub runner yet, so registered_runners == 0 even
            # though current_capacity > 0.  Scaling to 0 at this point would abort the
            # provision.  Check actual VMSS instance states to detect that window.
            if current_capacity > 0 and registered_runners == 0:
                instance_states = get_vmss_instance_states()
                if instance_states.get("creating", 0) > 0:
                    logging.info(
                        "Hold scale-to-zero: %d VMSS instance(s) still creating, 0 registered runners",
                        instance_states["creating"],
                    )
                    # desired_capacity unchanged — keep the in-flight provision alive
                else:
                    desired_capacity = 0
            else:
                # Runners registered (and all are idle), or capacity already 0
                desired_capacity = 0

        updated_capacity = set_capacity(desired_capacity)
        logging.info(
            "workflow_job '%s' | label='%s' | registered=%d busy=%d | capacity %d -> %d",
            action,
            get_runner_label(),
            registered_runners,
            busy_runners,
            current_capacity,
            updated_capacity,
        )

        return func.HttpResponse(
            json_response(
                {
                    "message": "processed",
                    "action": action,
                    "registeredRunners": registered_runners,
                    "busyRunners": busy_runners,
                    "currentCapacity": current_capacity,
                    "desiredCapacity": updated_capacity,
                }
            ),
            status_code=200,
            mimetype="application/json",
        )
    except Exception as exc:
        logging.exception("Failed to process workflow_job event '%s': %s", action, exc)
        return func.HttpResponse(
            json_response({"message": "error", "action": action, "detail": str(exc)}),
            status_code=500,
            mimetype="application/json",
        )
