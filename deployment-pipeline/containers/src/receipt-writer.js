const crypto = require("crypto");
const {
    S3Client,
    PutObjectCommand
} = require("@aws-sdk/client-s3");


function getReceiptConfiguration() {
    return {
        bucket: process.env.RECEIPTS_BUCKET || "",
        region: process.env.AWS_REGION || "eu-north-1",
        environment: process.env.NODE_ENV || "unknown"
    };
}


function createReceipt(paymentResult) {
    const receiptId =
        `rcpt-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;

    return {
        receiptId,
        service: "kk-payments",
        environment:
            process.env.NODE_ENV || "unknown",
        amount: paymentResult.amount,
        status: paymentResult.status,
        createdAt: new Date().toISOString()
    };
}


async function publishPaymentReceipt(
    paymentResult,
    injectedClient = null
) {
    const config = getReceiptConfiguration();

    /*
     * Production currently has no RECEIPTS_BUCKET.
     * Preserve the existing payment behaviour when
     * receipt integration is not configured.
     */
    if (!config.bucket) {
        return {
            status: "DISABLED"
        };
    }

    const receipt = createReceipt(paymentResult);
    const key = `incoming/${receipt.receiptId}.json`;

    const client =
        injectedClient ||
        new S3Client({
            region: config.region
        });

    await client.send(
        new PutObjectCommand({
            Bucket: config.bucket,
            Key: key,
            Body: JSON.stringify(receipt),
            ContentType: "application/json"
        })
    );

    console.log(
        JSON.stringify({
            event: "receipt_published",
            receiptId: receipt.receiptId,
            bucket: config.bucket,
            key
        })
    );

    return {
        status: "PUBLISHED",
        receiptId: receipt.receiptId,
        bucket: config.bucket,
        key
    };
}


module.exports = {
    createReceipt,
    getReceiptConfiguration,
    publishPaymentReceipt
};
