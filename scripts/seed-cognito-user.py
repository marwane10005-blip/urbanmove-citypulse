from __future__ import annotations

import argparse
import sys

import boto3
from botocore.exceptions import ClientError

def ensure_user(
    idp,
    user_pool_id: str,
    email: str,
    password: str,
    group: str,
) -> None:
    print(f"[1/3] Ensuring user {email} exists…")
    try:
        idp.admin_create_user(
            UserPoolId=user_pool_id,
            Username=email,
            UserAttributes=[
                {"Name": "email", "Value": email},
                {"Name": "email_verified", "Value": "true"},
            ],
            MessageAction="SUPPRESS",
            TemporaryPassword=password,
        )
        print("      created")
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "UsernameExistsException":
            print("      already exists")
        else:
            raise

    print("[2/3] Setting permanent password…")
    idp.admin_set_user_password(
        UserPoolId=user_pool_id,
        Username=email,
        Password=password,
        Permanent=True,
    )
    print("      done")

    print(f"[3/3] Adding to group {group}…")
    try:
        idp.admin_add_user_to_group(
            UserPoolId=user_pool_id,
            Username=email,
            GroupName=group,
        )
        print("      added")
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ResourceNotFoundException":
            print(
                f"ERROR: group '{group}' not found in pool {user_pool_id}. "
                f"Apply the cognito module first.",
                file=sys.stderr,
            )
            raise
        raise

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--user-pool-id", required=True)
    parser.add_argument("--email", default="operator@urbanmove.dev")
    parser.add_argument("--password", default="Demo1234!Operator")
    parser.add_argument("--group", default="fleet-operator")
    parser.add_argument("--region", default="eu-west-3")
    args = parser.parse_args()

    idp = boto3.client("cognito-idp", region_name=args.region)
    ensure_user(idp, args.user_pool_id, args.email, args.password, args.group)

    print(f"\nDemo login:\n  email:    {args.email}\n  password: {args.password}\n")
    print("WARNING: this password is public in git history. Rotate before any real deployment.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
