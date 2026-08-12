const fs = require("fs");

if (fs.existsSync("dist")) {
    fs.rmSync("dist", { recursive: true, force: true });
}

fs.mkdirSync("dist", { recursive: true });

fs.copyFileSync("src/index.js", "dist/index.js");
fs.copyFileSync("src/payments.js", "dist/payments.js");

console.log("Build completed.");