from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from typing import Any

import boto3
from botocore.exceptions import ClientError

THING_NAME = "urbanmove-simulator"

@dataclass
class Context:
    project: str
    environment: str
    region: str
    name_prefix: str

    @property
    def secret_name(self) -> str:
        return f"{self.name_prefix}/iot/simulator-cert"

    @property
    def policy_name(self) -> str:
        return f"{self.name_prefix}-device-policy"

    @property
    def thing_type_name(self) -> str:
        return f"{self.name_prefix}-vehicle"

def ensure_thing(iot, ctx: Context) -> dict[str, Any]:
    try:
        return iot.describe_thing(thingName=THING_NAME)
    except iot.exceptions.ResourceNotFoundException:
        return iot.create_thing(
            thingName=THING_NAME,
            thingTypeName=ctx.thing_type_name,
            attributePayload={
                "attributes": {
                    "fleet_id": "paris-demo",
                    "model": "simulator-v1",
                }
            },
        )

def create_cert(iot) -> dict[str, Any]:

    return iot.create_keys_and_certificate(setAsActive=True)

def attach_cert_and_policy(iot, ctx: Context, cert_arn: str) -> None:
    iot.attach_thing_principal(thingName=THING_NAME, principal=cert_arn)
    try:
        iot.attach_policy(policyName=ctx.policy_name, target=cert_arn)
    except iot.exceptions.ResourceNotFoundException:
        print(
            f"ERROR: IoT policy '{ctx.policy_name}' not found. "
            f"Apply Terraform first (module.iot).",
            file=sys.stderr,
        )
        raise

def get_iot_endpoint(iot) -> str:
    return iot.describe_endpoint(endpointType="iot:Data-ATS")["endpointAddress"]

def write_secret(sm, ctx: Context, payload: dict[str, Any]) -> str:
    body = json.dumps(payload, indent=2)
    try:
        resp = sm.create_secret(
            Name=ctx.secret_name,
            Description="IoT Core X.509 material for the fleet simulator. Shared cert (demo simplification).",
            SecretString=body,
            Tags=[
                {"Key": "Project", "Value": ctx.project},
                {"Key": "Environment", "Value": ctx.environment},
                {"Key": "Component", "Value": "simulator"},
            ],
        )
        return resp["ARN"]
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ResourceExistsException":
            resp = sm.put_secret_value(SecretId=ctx.secret_name, SecretString=body)
            return resp["ARN"]
        raise

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="urbanmove")
    parser.add_argument("--environment", default="dev")
    parser.add_argument("--region", default="eu-west-3")
    args = parser.parse_args()

    ctx = Context(
        project=args.project,
        environment=args.environment,
        region=args.region,
        name_prefix=f"{args.project}-{args.environment}",
    )

    session = boto3.Session(region_name=ctx.region)
    iot = session.client("iot")
    sm = session.client("secretsmanager")

    print(f"[1/5] Ensuring thing '{THING_NAME}' exists…")
    ensure_thing(iot, ctx)

    print("[2/5] Creating fresh keypair + certificate…")
    cert = create_cert(iot)
    cert_arn = cert["certificateArn"]
    cert_pem = cert["certificatePem"]
    private_key = cert["keyPair"]["PrivateKey"]
    print(f"      certificateArn: {cert_arn}")

    print(f"[3/5] Attaching cert to thing + policy '{ctx.policy_name}'…")
    attach_cert_and_policy(iot, ctx, cert_arn)

    print("[4/5] Reading IoT Core ATS endpoint…")
    endpoint = get_iot_endpoint(iot)
    print(f"      endpoint: {endpoint}")

    print(f"[5/5] Storing material in Secrets Manager secret '{ctx.secret_name}'…")
    secret_arn = write_secret(
        sm,
        ctx,
        {
            "thingName": THING_NAME,
            "certificateArn": cert_arn,
            "certificatePem": cert_pem,
            "privateKeyPem": private_key,
            "endpoint": endpoint,
        },
    )
    print(f"      secretArn: {secret_arn}")

    print("\nDone. The simulator should read this secret at startup.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
