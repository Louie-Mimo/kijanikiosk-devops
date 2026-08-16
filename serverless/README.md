# KijaniKiosk Staging Receipt Chain

The Track A receipt-chain implementation integrates the Kubernetes
`kk-payments` staging deployment with AWS S3 and AWS Lambda.

It demonstrates a complete event-driven flow in which a successful payment
creates a receipt, the receipt is processed asynchronously, and a notification
record is generated.

## Architecture

```text
GET /payment?amount=<amount>
        |
        v
kk-payments
(kijani-staging)
        |
        | PutObject
        v
s3://kk-payments-receipts-staging/incoming/
        |
        | s3:ObjectCreated:*
        v
kk-receipt-processor-staging
        |
        | creates
        v
processed/<receiptId>.json
        |
        | asynchronous Lambda invocation
        v
kk-receipt-notifier-staging
        |
        | creates
        v
notifications/<receiptId>.json
```

## End-to-End Flow

A request such as:

```bash
GET /payment?amount=2500
```

is handled by the `kk-payments` service.

The payment service:

1. Processes the payment.
2. Generates a unique receipt ID.
3. Creates a JSON receipt.
4. Writes the receipt to:

```text
s3://kk-payments-receipts-staging/incoming/<receiptId>.json
```

The S3 `ObjectCreated` event then invokes:

```text
kk-receipt-processor-staging
```

The processor reads the incoming receipt, marks it as processed, and writes:

```text
processed/<receiptId>.json
```

The processor then asynchronously invokes:

```text
kk-receipt-notifier-staging
```

The notifier creates the final notification record at:

```text
notifications/<receiptId>.json
```

## Receipt Lifecycle

The same `receiptId` is maintained throughout the complete chain.

```text
incoming/<receiptId>.json
        |
        v
processed/<receiptId>.json
        |
        v
notifications/<receiptId>.json
```

This makes the transaction traceable from the payment service through both
Lambda functions.

## Example Payment Response

A successful staging payment returns a response similar to:

```json
{
  "status": "SUCCESS",
  "amount": 2500,
  "receipt": {
    "status": "PUBLISHED",
    "receiptId": "rcpt-1786890391408-07143259",
    "bucket": "kk-payments-receipts-staging",
    "key": "incoming/rcpt-1786890391408-07143259.json"
  }
}
```

## Example Processed Receipt

The receipt processor adds processing information:

```json
{
  "receiptId": "rcpt-1786890391408-07143259",
  "service": "kk-payments",
  "environment": "staging",
  "amount": 2500,
  "status": "SUCCESS",
  "processingStatus": "PROCESSED"
}
```

## Example Notification

The notifier produces a notification record similar to:

```json
{
  "receiptId": "rcpt-1786890391408-07143259",
  "paymentStatus": "SUCCESS",
  "amount": 2500,
  "environment": "staging",
  "notificationStatus": "SENT"
}
```

## Staging Configuration

The `kk-payments` staging deployment uses:

```text
NODE_ENV=staging
AWS_REGION=eu-north-1
RECEIPTS_BUCKET=kk-payments-receipts-staging
```

The receipt bucket value is managed through the staging
`kk-payments-config` ConfigMap.

AWS credentials are supplied through the Kubernetes Secret:

```text
kk-payments-receipt-aws
```

The Secret contains:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Credential values must never be committed to Git or displayed in
documentation.

## Environment Isolation

Receipt publishing is enabled only when `RECEIPTS_BUCKET` is configured.

This allows the same `kk-payments` application image and Kubernetes Deployment
manifest to be used in both staging and production.

Current behaviour:

```text
Staging:
RECEIPTS_BUCKET=kk-payments-receipts-staging
Receipt publishing enabled

Production:
RECEIPTS_BUCKET not configured
Receipt publishing disabled
```

The Kubernetes Deployment references the receipt AWS Secret using:

```yaml
- secretRef:
    name: kk-payments-receipt-aws
    optional: true
```

This allows production to run without the staging AWS credential Secret.

## AWS Infrastructure

Terraform provisions the staging receipt-chain infrastructure.

The main resources are:

- S3 receipt bucket
- S3 public-access protection
- S3 server-side encryption
- S3 versioning
- receipt processor Lambda
- notifier Lambda
- Lambda execution IAM roles
- least-privilege Lambda IAM policies
- S3-to-Lambda invocation permission
- S3 ObjectCreated event notification
- staging payment receipt-writer IAM user
- least-privilege receipt-writer IAM policy

## S3 Bucket

The staging receipt bucket is:

```text
kk-payments-receipts-staging
```

It is configured as:

- private
- protected from public access
- AES-256 encrypted
- versioning enabled

## S3 Event Trigger

Only new JSON objects under:

```text
incoming/
```

trigger the processor Lambda.

The notification filter is:

```text
Event:  s3:ObjectCreated:*
Prefix: incoming/
Suffix: .json
```

Objects written under:

```text
processed/
notifications/
```

do not retrigger the processor.

This prevents an S3 event-processing loop.

## Receipt Processor Lambda

Function:

```text
kk-receipt-processor-staging
```

Responsibilities:

1. Receive the S3 ObjectCreated event.
2. Read the incoming receipt.
3. Add processing metadata.
4. Write the processed receipt to `processed/`.
5. Invoke the notifier Lambda asynchronously.
6. Write a structured CloudWatch log event.

Example log:

```json
{
  "event": "receipt_processed",
  "receiptId": "rcpt-...",
  "sourceKey": "incoming/rcpt-....json",
  "processedKey": "processed/rcpt-....json"
}
```

## Receipt Notifier Lambda

Function:

```text
kk-receipt-notifier-staging
```

Responsibilities:

1. Receive the processed receipt.
2. Generate notification metadata.
3. Write a notification record to `notifications/`.
4. Write a structured CloudWatch log event.

Example log:

```json
{
  "event": "receipt_notification_sent",
  "receiptId": "rcpt-...",
  "notificationKey": "notifications/rcpt-....json"
}
```

## Payment Service Integration

The `kk-payments` container uses the AWS SDK for JavaScript to publish the
incoming receipt.

The production container runs on Node.js 20.

The receipt writer logs a structured event after a successful S3 upload:

```json
{
  "event": "receipt_published",
  "receiptId": "rcpt-...",
  "bucket": "kk-payments-receipts-staging",
  "key": "incoming/rcpt-....json"
}
```

If no receipt bucket is configured, receipt integration returns:

```json
{
  "status": "DISABLED"
}
```

and the existing payment flow remains available.

## IAM Security Model

The staging payment application uses a dedicated IAM user:

```text
kk-payments-staging-receipt-writer
```

Its permission is limited to:

```text
s3:PutObject
```

for:

```text
arn:aws:s3:::kk-payments-receipts-staging/incoming/*
```

The payment service cannot write to:

```text
processed/
notifications/
```

Those locations are controlled by the Lambda execution roles.

The Terraform configuration intentionally does not create the IAM access key.

This prevents the AWS secret access key from being stored in Terraform state.

The access key is created separately and stored only in the Kubernetes
staging Secret.

## Source Layout

```text
serverless/
├── README.md
├── functions/
│   ├── notifier/
│   │   └── index.py
│   └── receipt-processor/
│       └── index.py
├── terraform/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── variables.tf
└── verify-receipt-chain.sh
```

Generated Terraform files are not committed:

```text
.terraform/
.build/
*.tfplan
*.tfstate
*.tfstate.*
```

## Terraform Deployment

Initialize:

```bash
terraform -chdir=serverless/terraform init
```

Format:

```bash
terraform -chdir=serverless/terraform fmt -recursive
```

Validate:

```bash
terraform -chdir=serverless/terraform validate
```

Generate a plan:

```bash
terraform -chdir=serverless/terraform plan \
  -out=receipt-chain.tfplan
```

Apply the reviewed plan:

```bash
terraform -chdir=serverless/terraform apply \
  receipt-chain.tfplan
```

## Infrastructure Verification

Confirm the bucket:

```bash
aws s3api head-bucket \
  --bucket kk-payments-receipts-staging
```

Confirm the processor:

```bash
aws lambda get-function \
  --function-name kk-receipt-processor-staging
```

Confirm the notifier:

```bash
aws lambda get-function \
  --function-name kk-receipt-notifier-staging
```

Confirm the S3 event notification:

```bash
aws s3api get-bucket-notification-configuration \
  --bucket kk-payments-receipts-staging
```

## End-to-End Verification

Make a real staging payment request:

```bash
curl \
  "http://127.0.0.1:13006/payment?amount=2500"
```

Extract the returned `receiptId`.

Then run:

```bash
./serverless/verify-receipt-chain.sh <receipt-id>
```

The verification script checks:

```text
incoming/<receiptId>.json
processed/<receiptId>.json
notifications/<receiptId>.json
```

A successful verification ends with:

```text
PASS: receipt chain completed for <receipt-id>
```

## Runtime Log Verification

### Payment service

```bash
kubectl logs \
  -n kijani-staging \
  -l app=kk-payments \
  --since=10m \
  --prefix=true
```

Look for:

```text
receipt_published
```

### Receipt processor

```bash
aws logs tail \
  /aws/lambda/kk-receipt-processor-staging \
  --since 10m \
  --format short
```

Look for:

```text
receipt_processed
```

### Receipt notifier

```bash
aws logs tail \
  /aws/lambda/kk-receipt-notifier-staging \
  --since 10m \
  --format short
```

Look for:

```text
receipt_notification_sent
```

## Proven End-to-End Result

The staging integration has been validated with a real payment request.

The verified flow was:

```text
/payment?amount=2500
        |
        v
SUCCESS
        |
        v
receipt.status=PUBLISHED
        |
        v
incoming/<receiptId>.json
        |
        v
receipt processor Lambda
        |
        v
processingStatus=PROCESSED
        |
        v
processed/<receiptId>.json
        |
        v
notifier Lambda
        |
        v
notificationStatus=SENT
        |
        v
notifications/<receiptId>.json
```

The same receipt ID was observed in the payment-service log, processor
CloudWatch log, notifier CloudWatch log, and all three S3 objects.

## Security Controls

The implementation includes the following controls:

- no AWS credentials committed to Git
- dedicated least-privilege staging writer identity
- private S3 bucket
- S3 public-access blocking
- S3 server-side encryption
- S3 versioning
- environment-specific bucket configuration
- optional staging credential Secret
- Terraform state excluded from Git
- Terraform plan files excluded from Git
- temporary credential files deleted after Secret creation
- Lambda permissions limited to required operations
- payment writer limited to `incoming/*`

## Limitations

This receipt chain is currently implemented for the staging environment.

Production receipt publishing remains disabled until a separate production
bucket, IAM identity, and production configuration are deliberately
provisioned.

The notifier currently demonstrates notification processing by writing a
notification record to S3. It does not send an external SMS or email.

The staging Kubernetes workload currently authenticates to AWS using a
dedicated IAM access key stored in a Kubernetes Secret. In a managed production
Kubernetes environment, workload identity or IAM Roles for Service Accounts
would be preferred over long-lived access keys.

## Track A Evidence

This implementation demonstrates:

```text
Staging payment
      |
      v
Receipt written
      |
      v
AWS event triggered
      |
      v
Receipt processed
      |
      v
Notifier executed
```

Evidence can be collected from:

- the payment HTTP response
- `kk-payments` Kubernetes logs
- S3 `incoming/`
- S3 `processed/`
- S3 `notifications/`
- receipt processor CloudWatch logs
- notifier CloudWatch logs
- Terraform configuration and outputs
