import boto3
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")

QUARANTINE_SG_NAME = "isolation-sg"


def get_quarantine_sg_id() -> str:
    """Look up the sg-quarantine security group ID by name."""
    response = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": [QUARANTINE_SG_NAME]}]
    )
    groups = response.get("SecurityGroups", [])
    if not groups:
        raise ValueError(f"Security group '{QUARANTINE_SG_NAME}' not found. Create it first.")
    return groups[0]["GroupId"]


def get_current_security_groups(instance_id: str) -> list[str]:
    """Return the list of current security group IDs attached to the instance."""
    response = ec2.describe_instances(InstanceIds=[instance_id])
    reservations = response.get("Reservations", [])
    if not reservations:
        raise ValueError(f"Instance '{instance_id}' not found.")
    instance = reservations[0]["Instances"][0]
    return [sg["GroupId"] for sg in instance.get("SecurityGroups", [])]


def quarantine_instance(instance_id: str) -> dict:
    """
    Swap all security groups on the given EC2 instance to sg-quarantine.
    Returns a summary of what changed.
    """
    quarantine_sg_id = get_quarantine_sg_id()
    old_sgs = get_current_security_groups(instance_id)

    logger.info(f"Instance {instance_id} — current SGs: {old_sgs}")
    logger.info(f"Switching to quarantine SG: {quarantine_sg_id}")

    ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=[quarantine_sg_id],
    )

    logger.info(f"Instance {instance_id} is now quarantined.")

    return {
        "instance_id": instance_id,
        "old_security_groups": old_sgs,
        "new_security_group": quarantine_sg_id,
        "status": "quarantined",
    }


def lambda_handler(event, context):
    """
    Entry point for the Lambda function.

    Expected input (from Shuffle webhook or EventBridge):
    {
        "instance_id": "i-0abc123def456"
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")

    instance_id = event.get("instance_id")
    if not instance_id:
        raise ValueError("Missing required field: 'instance_id'")

    result = quarantine_instance(instance_id)
    logger.info(f"Quarantine result: {result}")

    return {
        "statusCode": 200,
        "body": result,
    }