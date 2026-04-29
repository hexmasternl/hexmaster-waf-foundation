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
    log_env_summary,
    set_capacity,
)

# Log at module load so App Insights confirms the function module initialised.
logging.info("workflow_job_webhook module loaded")


def _is_valid_signature(body: bytes, signature_header: str) -> bool:
    secret = get_webhook_secret()
    if not secret or secret.startswith("@Microsoft.KeyVault"):
        logging.error(
            "GITHUB_WEBHOOK_SECRET is not resolved. "
            "Signature validation will always fail. "
            "Ensure the Key Vault secret 'runner-webhook-secret' exists and the "
            "Function App identity has 'Key Vault Secrets User' on the vault. "
            "Current value starts with: %s",
            (secret or "")[:30],
        )
        return False
    expected = "sha256=" + hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
    match = hmac.compare_digest(expected, signature_header or "")
    if not match:
        logging.warning(
            "Signature mismatch. Received header: '%s…' (first 20 chars). "
            "Ensure the webhook secret in GitHub matches GITHUB_WEBHOOK_SECRET in the Function App.",
            (signature_header or "")[:20],
        )
    return match


def main(req: func.HttpRequest) -> func.HttpResponse:
    body = req.get_body()
    signature = req.headers.get("X-Hub-Signature-256", "")
    event_name = req.headers.get("X-GitHub-Event", "")
    delivery_id = req.headers.get("X-GitHub-Delivery", "(unknown)")

    logging.info(
        "Webhook received: event=%s delivery=%s body_len=%d",
        event_name, delivery_id, len(body),
    )

    # Dump all resolved env vars at INFO level on each invocation so operators
    # can confirm configuration in App Insights without redeploying.
    log_env_summary()

    if event_name != "workflow_job":
        logging.info("Ignoring event '%s' (only 'workflow_job' is handled).", event_name)
        return func.HttpResponse(
            json_response({"message": "ignored", "reason": "event_not_supported"}),
            status_code=202,
            mimetype="application/json",
        )

    if not _is_valid_signature(body, signature):
        logging.warning("Request rejected: invalid HMAC-SHA256 signature (delivery=%s).", delivery_id)
        return func.HttpResponse(
            json_response({"message": "invalid signature"}),
            status_code=401,
            mimetype="application/json",
        )

    payload = req.get_json()
    workflow_job = payload.get("workflow_job", {})
    action = payload.get("action", "(unknown)")
    job_id = workflow_job.get("id")
    job_name = workflow_job.get("name")
    job_labels = workflow_job.get("labels", [])
    job_runner_id = workflow_job.get("runner_id")
    repository = payload.get("repository", {}).get("full_name", "(unknown)")

    logging.info(
        "workflow_job event: action=%s job_id=%s job_name=%s labels=%s runner_id=%s repo=%s",
        action, job_id, job_name, job_labels, job_runner_id, repository,
    )

    if not is_target_job(payload):
        logging.info(
            "Job %s (%s) does not match this runner pool — ignoring (delivery=%s).",
            job_id, job_name, delivery_id,
        )
        return func.HttpResponse(
            json_response({"message": "ignored", "reason": "runner_pool_mismatch"}),
            status_code=202,
            mimetype="application/json",
        )

    logging.info("Job %s (%s) matches this pool — processing action='%s'.", job_id, job_name, action)

    try:
        current_capacity = get_current_capacity()
        logging.info("Current VMSS capacity: %d", current_capacity)

        registered_runners, busy_runners = list_runners()
        logging.info("Runner snapshot: registered=%d busy=%d", registered_runners, busy_runners)

        desired_capacity = current_capacity

        if action == "queued":
            desired_capacity = min(max(current_capacity, busy_runners) + 1, get_max_runners())
            logging.info(
                "Scale-UP decision: current=%d busy=%d -> desired=%d (max=%d)",
                current_capacity, busy_runners, desired_capacity, get_max_runners(),
            )

        elif action == "completed" and busy_runners == 0:
            if job_runner_id:
                # Job was actually executed — the ephemeral runner deregistered itself.
                desired_capacity = 0
                logging.info(
                    "Scale-DOWN to 0: job completed by runner_id=%s, no busy runners.",
                    job_runner_id,
                )
            elif current_capacity > 0 and registered_runners == 0:
                # Job did not run (timeout / cancel).  VMs may still be bootstrapping.
                logging.info(
                    "Completed event with no runner_id and 0 registered runners — "
                    "checking VMSS instance states to detect bootstrapping VMs …"
                )
                instance_states = get_vmss_instance_states()
                non_failed = instance_states.get("total", 0) - instance_states.get("failed", 0)
                if non_failed > 0:
                    logging.info(
                        "Hold scale-to-zero: %d active VMSS instance(s) still bootstrapping "
                        "(states: %s). Keeping capacity at %d.",
                        non_failed, instance_states, current_capacity,
                    )
                    # desired_capacity unchanged
                else:
                    desired_capacity = 0
                    logging.info(
                        "No active VMSS instances found (states: %s) — scaling to 0.",
                        instance_states,
                    )
            else:
                desired_capacity = 0
                logging.info(
                    "Scale-DOWN to 0: busy=0, registered=%d, capacity=%d — no active work.",
                    registered_runners, current_capacity,
                )

        elif action == "completed":
            logging.info(
                "Completed event but busy_runners=%d — keeping capacity at %d.",
                busy_runners, current_capacity,
            )
        else:
            logging.info("Action '%s' requires no capacity change.", action)

        updated_capacity = set_capacity(desired_capacity)
        logging.info(
            "workflow_job '%s' DONE | label='%s' | registered=%d busy=%d | "
            "capacity %d -> %d (delivery=%s)",
            action,
            get_runner_label(),
            registered_runners,
            busy_runners,
            current_capacity,
            updated_capacity,
            delivery_id,
        )

        return func.HttpResponse(
            json_response(
                {
                    "message": "processed",
                    "action": action,
                    "deliveryId": delivery_id,
                    "jobId": job_id,
                    "jobName": job_name,
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
        logging.error(
            "UNHANDLED EXCEPTION processing workflow_job '%s' (delivery=%s job_id=%s job_name=%s repo=%s): %s",
            action, delivery_id, job_id, job_name, repository, exc,
            exc_info=True,
        )
        return func.HttpResponse(
            json_response(
                {
                    "message": "error",
                    "action": action,
                    "deliveryId": delivery_id,
                    "detail": str(exc),
                }
            ),
            status_code=500,
            mimetype="application/json",
        )
