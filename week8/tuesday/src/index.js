const http = require("http");
const { processPayment } = require("./payments");

const PORT = Number(process.env.PORT || 3000);
const VERSION = process.env.APP_VERSION || "v1.0.0";

const server = http.createServer((req, res) => {
    res.setHeader("Content-Type", "application/json");

    if (req.method === "GET" && req.url === "/health") {
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

    if (req.method === "GET" && req.url.startsWith("/payment")) {
        const url = new URL(req.url, `http://${req.headers.host}`);
        const amount = Number(url.searchParams.get("amount") || 0);

        res.writeHead(200);
        res.end(JSON.stringify(processPayment(amount)));
        return;
    }

    res.writeHead(404);
    res.end(JSON.stringify({ error: "Not Found" }));
});

server.listen(PORT, "0.0.0.0", () => {
    console.log(
        `kk-payments ${VERSION} listening on port ${PORT}`
    );
});