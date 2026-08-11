function processPayment(amount) {
    return {
        status: "SUCCESS",
        amount: amount
    };
}

module.exports = { processPayment };
