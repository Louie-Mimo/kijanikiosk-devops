const { processPayment } = require('../src/index');

test('payment succeeds', () => {
    const result = processPayment(100);

    expect(result.status).toBe("SUCCESS");
    expect(result.amount).toBe(100);
});
