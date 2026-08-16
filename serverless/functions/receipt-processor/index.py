import json
import os
import urllib.parse
from datetime import datetime, timezone

import boto3


s3 = boto3.client("s3")
lambda_client = boto3.client("lambda")

NOTIFIER_FUNCTION = os.environ["NOTIFIER_FUNCTION"]


def handler(event, context):
    processed = []

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(
            record["s3"]["object"]["key"]
        )

        response = s3.get_object(
            Bucket=bucket,
            Key=key,
        )

        receipt = json.loads(
            response["Body"].read().decode("utf-8")
        )

        receipt_id = receipt["receiptId"]

        processed_receipt = {
            **receipt,
            "processingStatus": "PROCESSED",
            "processedAt": datetime.now(
                timezone.utc
            ).isoformat(),
        }

        processed_key = f"processed/{receipt_id}.json"

        s3.put_object(
            Bucket=bucket,
            Key=processed_key,
            Body=json.dumps(processed_receipt).encode("utf-8"),
            ContentType="application/json",
        )

        lambda_client.invoke(
            FunctionName=NOTIFIER_FUNCTION,
            InvocationType="Event",
            Payload=json.dumps(processed_receipt).encode("utf-8"),
        )

        print(
            json.dumps(
                {
                    "event": "receipt_processed",
                    "receiptId": receipt_id,
                    "sourceKey": key,
                    "processedKey": processed_key,
                }
            )
        )

        processed.append(receipt_id)

    return {
        "statusCode": 200,
        "processed": processed,
    }
