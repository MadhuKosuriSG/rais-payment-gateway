# 🧪 TESTING GUIDE

Complete guide for testing your Razorpay payment integration.

---

## 📋 Test Scenarios

### ✅ Scenario 1: Successful Payment

**Objective:** Test complete payment flow from creation to capture

**Steps:**

1. **Create Payment**
```bash
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 499.00,
    "idempotency_key": "test-success-001",
    "metadata": {
      "product_id": 1,
      "user_email": "success@test.com"
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "payment": {
    "id": 1,
    "public_reference": "PAY_...",
    "status": "created"
  }
}
```

2. **Create Razorpay Order**
```bash
curl -X POST http://localhost:3000/payments/1/create_order
```

**Expected Response:**
```json
{
  "success": true,
  "razorpay_order_id": "order_...",
  "key_id": "rzp_test_..."
}
```

3. **Complete Payment in Razorpay Checkout**
- Use test card: `4111 1111 1111 1111`
- Expiry: Any future date
- CVV: Any 3 digits

4. **Verify Webhook Received**
```bash
rails console
> WebhookEvent.last
# Should show payment.captured event
```

5. **Check Payment Status**
```bash
curl http://localhost:3000/payments/1
```

**Expected Response:**
```json
{
  "success": true,
  "payment": {
    "status": "captured",
    "payment_attempts": [
      {
        "status": "captured",
        "gateway_transactions": [
          {
            "status": "captured",
            "razorpay_payment_id": "pay_..."
          }
        ]
      }
    ]
  }
}
```

**Verification Checklist:**
- [ ] Payment status is `captured`
- [ ] PaymentAttempt status is `captured`
- [ ] GatewayTransaction exists with `razorpay_payment_id`
- [ ] WebhookEvent exists and `processed = true`

---

### ❌ Scenario 2: Failed Payment

**Objective:** Test payment failure handling

**Steps:**

1. Create payment (same as Scenario 1)

2. Create Razorpay order (same as Scenario 1)

3. **Use Failure Test Card**
- Card: `4000 0000 0000 0002`
- This card always fails

4. **Verify Webhook Received**
```bash
rails console
> WebhookEvent.where(event_type: 'payment.failed').last
```

5. **Check Payment Status**
```bash
curl http://localhost:3000/payments/1
```

**Expected Response:**
```json
{
  "payment": {
    "status": "failed"
  }
}
```

**Verification Checklist:**
- [ ] Payment status is `failed`
- [ ] PaymentAttempt status is `failed`
- [ ] GatewayTransaction has `error_code` and `error_description`
- [ ] WebhookEvent for `payment.failed` exists

---

### 🔄 Scenario 3: Payment Retry

**Objective:** Test retry flow after failed payment

**Steps:**

1. Complete Scenario 2 (failed payment)

2. **Retry by creating new order**
```bash
curl -X POST http://localhost:3000/payments/1/create_order
```

**Expected:**
- New `razorpay_order_id` returned
- New PaymentAttempt created with `attempt_number: 2`

3. **Complete payment with success card**
- Card: `4111 1111 1111 1111`

4. **Verify Database State**
```bash
rails console
> payment = Payment.find(1)
> payment.payment_attempts.count
# Should be 2

> payment.payment_attempts.pluck(:status, :attempt_number)
# Should show: [["failed", 1], ["captured", 2]]
```

**Verification Checklist:**
- [ ] Two PaymentAttempts exist for same Payment
- [ ] First attempt is `failed`
- [ ] Second attempt is `captured`
- [ ] Payment status is `captured`

---

### 🔁 Scenario 4: Idempotency Test

**Objective:** Verify duplicate payment prevention

**Steps:**

1. **Create payment with specific idempotency key**
```bash
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 499.00,
    "idempotency_key": "idempotent-test-001",
    "metadata": {}
  }'
```

**Note the payment ID from response**

2. **Send EXACT same request again**
```bash
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 499.00,
    "idempotency_key": "idempotent-test-001",
    "metadata": {}
  }'
```

**Expected:**
- Same payment ID returned
- No new payment created

3. **Verify in database**
```bash
rails console
> Payment.where(idempotency_key: 'idempotent-test-001').count
# Should be 1 (not 2)
```

**Verification Checklist:**
- [ ] Same payment returned on duplicate request
- [ ] Only one payment exists in database
- [ ] No error thrown

---

### 🔐 Scenario 5: Webhook Signature Verification

**Objective:** Test webhook security

**Steps:**

1. **Send webhook with INVALID signature**
```bash
curl -X POST http://localhost:3000/webhooks/razorpay \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Event-Id: event_test_invalid" \
  -H "X-Razorpay-Signature: invalid_signature_here" \
  -d '{
    "event": "payment.captured",
    "payload": {
      "payment": {
        "entity": {
          "id": "pay_fake_123",
          "order_id": "order_fake_123",
          "amount": 49900,
          "status": "captured"
        }
      }
    }
  }'
```

**Expected Response:**
```json
{
  "success": false,
  "errors": ["Invalid webhook signature"]
}
```

**Verification Checklist:**
- [ ] Webhook rejected
- [ ] No payment status updated
- [ ] Error logged

---

### 🌐 Scenario 6: Duplicate Webhook

**Objective:** Test webhook idempotency

**Steps:**

1. **Send valid webhook**
```bash
# First, create a payment and order
# Then simulate webhook (use actual event_id from Razorpay test)
```

2. **Send SAME webhook again (same event_id)**

**Expected:**
- Second webhook returns success
- But no duplicate processing
- WebhookEvent.processed remains true

3. **Verify in database**
```bash
rails console
> WebhookEvent.where(event_id: 'event_test_123').count
# Should be 1 (not 2)
```

**Verification Checklist:**
- [ ] Only one WebhookEvent created
- [ ] Second request returns success
- [ ] No duplicate GatewayTransaction created

---

## 🧰 Testing Tools

### 1. Rails Console

```bash
rails console

# Check payment
> Payment.last

# Check attempts
> PaymentAttempt.last

# Check transactions
> GatewayTransaction.last

# Check webhooks
> WebhookEvent.recent.limit(5)

# Check unprocessed webhooks
> WebhookEvent.unprocessed

# Check success rate
> total = Payment.count
> successful = Payment.where(status: 'captured').count
> success_rate = (successful.to_f / total * 100).round(2)
> puts "Success rate: #{success_rate}%"
```

### 2. Database Console

```bash
rails dbconsole

-- Check all payments
SELECT * FROM payments ORDER BY created_at DESC LIMIT 10;

-- Check payment with attempts and transactions
SELECT 
  p.public_reference,
  p.status as payment_status,
  pa.razorpay_order_id,
  pa.status as attempt_status,
  gt.razorpay_payment_id,
  gt.status as transaction_status
FROM payments p
LEFT JOIN payment_attempts pa ON p.id = pa.payment_id
LEFT JOIN gateway_transactions gt ON pa.id = gt.payment_attempt_id
ORDER BY p.created_at DESC
LIMIT 10;

-- Check unprocessed webhooks
SELECT * FROM webhook_events WHERE processed = FALSE;
```

### 3. Log Monitoring

```bash
# Watch logs in real-time
tail -f log/development.log

# Filter for errors
tail -f log/development.log | grep ERROR

# Filter for payment events
tail -f log/development.log | grep Payment
```

---

## 📊 Test Data Verification

### After Each Test, Verify:

1. **Database Consistency**
```sql
-- All gateway_transactions should have a payment_attempt
SELECT COUNT(*) FROM gateway_transactions gt
LEFT JOIN payment_attempts pa ON gt.payment_attempt_id = pa.id
WHERE pa.id IS NULL;
-- Should be 0

-- All payment_attempts should have a payment
SELECT COUNT(*) FROM payment_attempts pa
LEFT JOIN payments p ON pa.payment_id = p.id
WHERE p.id IS NULL;
-- Should be 0
```

2. **Status Consistency**
```sql
-- Payment status should match latest attempt status
SELECT 
  p.id,
  p.status as payment_status,
  pa.status as latest_attempt_status
FROM payments p
JOIN payment_attempts pa ON p.id = pa.payment_id
WHERE pa.id = (
  SELECT id FROM payment_attempts 
  WHERE payment_id = p.id 
  ORDER BY attempt_number DESC 
  LIMIT 1
)
AND p.status != pa.status;
-- Should return 0 rows
```

---

## 🎯 Performance Testing

### Load Test with Apache Bench

```bash
# Test payment creation endpoint
ab -n 100 -c 10 -p payment.json -T application/json \
  http://localhost:3000/payments

# payment.json:
{
  "amount": 499.00,
  "idempotency_key": "load-test-001",
  "metadata": {}
}
```

**Expected:**
- No errors
- Response time < 500ms
- All requests return same payment (idempotency)

---

## ✅ Pre-Production Checklist

Before going live:

- [ ] All test scenarios pass
- [ ] Webhook signature verification works
- [ ] Idempotency prevents duplicates
- [ ] Failed payments can be retried
- [ ] Database indexes exist
- [ ] CORS configured correctly
- [ ] Environment variables set
- [ ] Razorpay webhook configured
- [ ] SSL enabled (production)
- [ ] Monitoring set up
- [ ] Error tracking configured
- [ ] Backup strategy in place

---

## 🐛 Common Issues & Solutions

### Issue: Webhook not received

**Debug:**
```bash
# Check webhook configuration in Razorpay dashboard
# Verify webhook URL is accessible
# Check Rails logs for incoming requests
tail -f log/development.log | grep webhooks
```

### Issue: Payment stuck in "initiated"

**Debug:**
```bash
rails console
> payment = Payment.find(1)
> payment.latest_attempt
> WebhookEvent.where(razorpay_order_id: payment.latest_attempt.razorpay_order_id)
```

### Issue: Duplicate payments created

**Debug:**
```bash
rails console
> Payment.group(:idempotency_key).having('COUNT(*) > 1').count
# Should be empty
```

---

**Happy Testing! 🎉**

Remember: Test thoroughly before handling real money!
