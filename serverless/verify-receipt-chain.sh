#!/usr/bin/env bash

set -euo pipefail

BUCKET="${BUCKET:-kk-payments-receipts-staging}"
REGION="${AWS_REGION:-eu-north-1}"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <receipt-id>"
    exit 2
fi

RECEIPT_ID="$1"

echo "========================================"
echo "KIJANIKIOSK RECEIPT CHAIN VERIFICATION"
echo "========================================"
echo "Receipt ID : $RECEIPT_ID"
echo "Bucket     : $BUCKET"
echo "Region     : $REGION"

check_object() {
    local label="$1"
    local key="$2"

    if aws s3api head-object \
        --region "$REGION" \
        --bucket "$BUCKET" \
        --key "$key" \
        >/dev/null 2>&1; then

        echo "PASS: $label -> $key"
    else
        echo "FAIL: $label missing -> $key"
        return 1
    fi
}

echo
echo "=== S3 OBJECT CHAIN ==="

check_object \
    "incoming receipt" \
    "incoming/${RECEIPT_ID}.json"

check_object \
    "processed receipt" \
    "processed/${RECEIPT_ID}.json"

check_object \
    "notification" \
    "notifications/${RECEIPT_ID}.json"

echo
echo "=== PROCESSED RECEIPT ==="

aws s3 cp \
    --region "$REGION" \
    "s3://${BUCKET}/processed/${RECEIPT_ID}.json" \
    -

echo
echo
echo "=== NOTIFICATION ==="

aws s3 cp \
    --region "$REGION" \
    "s3://${BUCKET}/notifications/${RECEIPT_ID}.json" \
    -

echo
echo
echo "=== RESULT ==="
echo "PASS: receipt chain completed for ${RECEIPT_ID}"
