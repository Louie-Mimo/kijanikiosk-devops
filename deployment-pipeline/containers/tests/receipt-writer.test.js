const {
    createReceipt,
    publishPaymentReceipt
} = require("../src/receipt-writer");


describe("receipt writer", () => {
    const originalEnvironment = {
        RECEIPTS_BUCKET:
            process.env.RECEIPTS_BUCKET,
        AWS_REGION:
            process.env.AWS_REGION,
        NODE_ENV:
            process.env.NODE_ENV
    };


    afterEach(() => {
        if (
            originalEnvironment.RECEIPTS_BUCKET ===
            undefined
        ) {
            delete process.env.RECEIPTS_BUCKET;
        } else {
            process.env.RECEIPTS_BUCKET =
                originalEnvironment.RECEIPTS_BUCKET;
        }

        if (
            originalEnvironment.AWS_REGION ===
            undefined
        ) {
            delete process.env.AWS_REGION;
        } else {
            process.env.AWS_REGION =
                originalEnvironment.AWS_REGION;
        }

        if (
            originalEnvironment.NODE_ENV ===
            undefined
        ) {
            delete process.env.NODE_ENV;
        } else {
            process.env.NODE_ENV =
                originalEnvironment.NODE_ENV;
        }
    });


    test(
        "creates a receipt from a successful payment",
        () => {
            process.env.NODE_ENV = "staging";

            const receipt = createReceipt({
                status: "SUCCESS",
                amount: 2500
            });

            expect(receipt.service)
                .toBe("kk-payments");

            expect(receipt.environment)
                .toBe("staging");

            expect(receipt.amount)
                .toBe(2500);

            expect(receipt.status)
                .toBe("SUCCESS");

            expect(receipt.receiptId)
                .toMatch(/^rcpt-/);
        }
    );


    test(
        "is disabled when no receipt bucket is configured",
        async () => {
            delete process.env.RECEIPTS_BUCKET;

            const result =
                await publishPaymentReceipt({
                    status: "SUCCESS",
                    amount: 100
                });

            expect(result.status)
                .toBe("DISABLED");
        }
    );


    test(
        "writes receipt to incoming prefix when enabled",
        async () => {
            process.env.RECEIPTS_BUCKET =
                "kk-payments-receipts-staging";

            process.env.AWS_REGION =
                "eu-north-1";

            process.env.NODE_ENV =
                "staging";

            const send = jest
                .fn()
                .mockResolvedValue({});

            const fakeClient = {
                send
            };

            const result =
                await publishPaymentReceipt(
                    {
                        status: "SUCCESS",
                        amount: 2500
                    },
                    fakeClient
                );

            expect(result.status)
                .toBe("PUBLISHED");

            expect(result.bucket)
                .toBe(
                    "kk-payments-receipts-staging"
                );

            expect(result.key)
                .toMatch(
                    /^incoming\/rcpt-.*\.json$/
                );

            expect(send)
                .toHaveBeenCalledTimes(1);

            const command =
                send.mock.calls[0][0];

            expect(command.input.Bucket)
                .toBe(
                    "kk-payments-receipts-staging"
                );

            expect(command.input.Key)
                .toBe(result.key);
        }
    );
});
