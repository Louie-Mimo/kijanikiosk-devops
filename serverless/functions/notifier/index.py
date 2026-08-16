import json
import os
from datetime import datetime, timezone

import boto3


s3 = boto3.client("s3")

RECEIPTS_BUCKET = os.environ["RECEIPTS_BUCKET"]


def handler(event, context):
    receipt_id = event["receiptId"]

    notification = {
        "receiptId": receipt_id,
        "paymentStatus": event.get("status"),
        "amount": event.get("amount"),
        "environment": event.get("environment"),
        "notificationStatus": "SENT",
        "notifiedAt": datetime.now(
            timezone.utc
        ).isoformat(),
    }

    key = f"notifications/{receipt_id}.json"

    s3.put_object(
        Bucket=RECEIPTS_BUCKET,
        Key=key,
        Body=json.dumps(notification).encode("utf-8"),
        ContentType="application/json",
    )

    print(
        json.dumps(
            {
                "event": "receipt_notification_sent",
                "receiptId": receipt_id,
                "notificationKey": key,
            }
        )
    )

    return notification
