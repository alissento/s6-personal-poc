import boto3
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")

def get_instance_subnet_id(instance_id: str) -> str:
    """Return the Subnet ID attached to the instance."""
    response = ec2.describe_instances(InstanceIds=[instance_id])
    reservations = response.get("Reservations", [])
    if not reservations:
        raise ValueError(f"Instance '{instance_id}' not found.")
    return reservations[0]["Instances"][0]["SubnetId"]

def get_network_acl_id(subnet_id: str) -> str:
    """Return the Network ACL ID associated with the Subnet."""
    response = ec2.describe_network_acls(
        Filters=[{"Name": "association.subnet-id", "Values": [subnet_id]}]
    )
    acls = response.get("NetworkAcls", [])
    if not acls:
        raise ValueError(f"No Network ACL found for Subnet '{subnet_id}'.")
    return acls[0]["NetworkAclId"]

def get_next_rule_number(nacl_id: str, acl_entries: list, egress: bool) -> int:
    """Find the first available rule number (from 100) for the NACL."""
    existing_rules = [e["RuleNumber"] for e in acl_entries if e["Egress"] == egress and e["RuleNumber"] < 32767]
    for i in range(100, 32767):
        if i not in existing_rules:
            return i
    raise ValueError(f"No available rule numbers in NACL '{nacl_id}'.")

def block_ip_in_nacl(nacl_id: str, ip_address: str) -> dict:
    """
    Block an IP address by adding deny rules to the Network ACL.
    Returns a summary of what changed.
    """
    cidr_block = f"{ip_address}/32"
    
    response = ec2.describe_network_acls(NetworkAclIds=[nacl_id])
    acl = response["NetworkAcls"][0]
    entries = acl.get("Entries", [])
    
    existing_inbound = any(e.get("CidrBlock") == cidr_block and not e["Egress"] for e in entries)
    existing_outbound = any(e.get("CidrBlock") == cidr_block and e["Egress"] for e in entries)
    
    inbound_rule = None
    outbound_rule = None
    
    if not existing_inbound:
        inbound_rule = get_next_rule_number(nacl_id, entries, egress=False)
        ec2.create_network_acl_entry(
            NetworkAclId=nacl_id,
            RuleNumber=inbound_rule,
            Protocol="-1",
            RuleAction="deny",
            Egress=False,
            CidrBlock=cidr_block
        )
        logger.info(f"Created inbound deny entry {inbound_rule} for {cidr_block}")

    if not existing_outbound:
        outbound_rule = get_next_rule_number(nacl_id, entries, egress=True)
        ec2.create_network_acl_entry(
            NetworkAclId=nacl_id,
            RuleNumber=outbound_rule,
            Protocol="-1",
            RuleAction="deny",
            Egress=True,
            CidrBlock=cidr_block
        )
        logger.info(f"Created outbound deny entry {outbound_rule} for {cidr_block}")

    return {
        "nacl_id": nacl_id,
        "ip_blocked": cidr_block,
        "inbound_rule_number": inbound_rule,
        "outbound_rule_number": outbound_rule,
        "already_existed": existing_inbound and existing_outbound
    }


def lambda_handler(event, context):
    """
    Entry point for the Lambda function.

    Expected input (from Shuffle webhook or EventBridge):
    {
        "instance_id": "i-0abc123def456",
        "ip_address": "8.8.8.8"
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")

    instance_id = event.get("instance_id")
    ip_address = event.get("ip_address")
    
    if not instance_id or not ip_address:
        raise ValueError("Missing required fields: 'instance_id' and/or 'ip_address'")

    subnet_id = get_instance_subnet_id(instance_id)
    nacl_id = get_network_acl_id(subnet_id)
    
    result = block_ip_in_nacl(nacl_id, ip_address)
    logger.info(f"NACL Block result: {result}")

    return {
        "statusCode": 200,
        "body": result,
    }