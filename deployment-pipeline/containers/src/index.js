const http = require("http");

const {
    processPayment
} = require("./payments");

const {
    publishPaymentReceipt
} = require("./receipt-writer");


const PORT = Number(process.env.PORT || 3000);
const VERSION = process.env.APP_VERSION || "v1.0.0";


const server = http.createServer(async (req, res) => {
    res.setHeader(
        "Content-Type",
        "application/json"
    );

    if (
        req.method === "GET" &&
        req.url === "/health"
    ) {
        res.writeHead(200);

        res.end(
            JSON.stringify({
                status: "ok",
                service: "kk-payments",
                version: VERSION,
                port: PORT
            })
        );

        return;
    }

    if (
        req.method === "GET" &&
        req.url.startsWith("/payment")
    ) {
        const url = new URL(
            req.url,
            `http://${req.headers.host}`
        );

        const amount = Number(
            url.searchParams.get("amount") || 0
        );

        const paymentResult =
            processPayment(amount);

        try {
            const receipt =
                await publishPaymentReceipt(
                    paymentResult
                );

            res.writeHead(200);

            res.end(
                JSON.stringify({
                    ...paymentResult,
                    receipt
                })
            );
        } catch (error) {
            console.error(
                JSON.stringify({
                    event: "receipt_publish_failed",
                    message: error.message
                })
            );

            /*
             * When receipt publishing is explicitly
             * configured, treat a failed write as an
             * integration failure so staging catches it.
             */
            res.writeHead(502);

            res.end(
                JSON.stringify({
                    status: "ERROR",
                    error:
                        "Receipt publication failed"
                })
            );
        }

        return;
    }

    res.writeHead(404);

    res.end(
        JSON.stringify({
            error: "Not Found"
        })
    );
});


server.listen(
    PORT,
    "0.0.0.0",
    () => {
        console.log(
            `kk-payments ${VERSION} listening on port ${PORT}`
        );
    }
);
