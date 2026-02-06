# 📘 COMPLETE IMPLEMENTATION GUIDE

## Production-Grade Razorpay Payment System - Deep Dive

This document provides a **complete, step-by-step explanation** of how the payment system works, covering every critical decision and edge case.

---

## 🎯 Core Principles

### 1. Webhooks are the Source of Truth

**Why?**
- Frontend callbacks can be manipulated
- Network failures can prevent frontend from receiving success
- User might close browser before callback executes
- Webhooks are server-to-server (secure, reliable)

**Implementation:**
- NEVER mark payment as successful based on frontend callback
- Always wait for webhook confirmation
- Frontend should poll for status after payment

### 2. Idempotency Everywhere

**Why?**
- User might double-click "Pay" button
- Network retries might duplicate requests
- Webhooks might be sent multiple times by Razorpay

**Implementation:**
- `idempotency_key` (frontend-generated UUID) prevents duplicate payments
- `event_id` (Razorpay-generated) prevents duplicate webhook processing
- Database unique constraints enforce idempotency at DB level

### 3. Complete Audit Trail

**Why?**
- Debugging payment issues
- Accounting and reconciliation
- Compliance and tax requirements
- Customer support

**Implementation:**
- Never delete records, only update status
- Store all webhook payloads
- Track every state transition
- Log all API calls

---

## 🔑 Key Identifiers Explained

### 1. `public_reference` (Backend-Generated)

**Format:** `PAY_ABC123XYZ`

**When generated:** When `Payment` record is created

**Purpose:**
- User-visible payment ID
- Safe to show in URLs, emails, support tickets
- Used for customer support queries

**Code:**
```ruby
def generate_public_reference
  loop do
    self.public_reference = "PAY_#{SecureRandom.alphanumeric(12).upcase}"
    break unless Payment.exists?(public_reference: public_reference)
  end
end
```

### 2. `idempotency_key` (Frontend-Generated)

**Format:** UUID v4 (e.g., `550e8400-e29b-41d4-a716-446655440000`)

**When generated:** Before calling `POST /payments`

**Purpose:**
- Prevent duplicate payments from double-clicks
- Enforce "exactly once" payment creation
- If same key is sent again, return existing payment

**Frontend code:**
```javascript
import { v4 as uuidv4 } from 'uuid';

const idempotencyKey = uuidv4();
```

**Backend enforcement:**
```ruby
existing_payment = Payment.find_by(idempotency_key: idempotency_key)
return existing_payment if existing_payment
```

### 3. `razorpay_order_id` (Razorpay-Generated)

**Format:** `order_xyz123abc`

**When generated:** When calling Razorpay API to create order

**Purpose:**
- Razorpay's identifier for the order
- Used in Razorpay Checkout
- Links payment to our system

**Code:**
```ruby
razorpay_order = Razorpay::Order.create(
  amount: amount_in_paise,
  currency: 'INR',
  receipt: payment.public_reference
)

razorpay_order.id # => "order_xyz123abc"
```

### 4. `razorpay_payment_id` (Razorpay-Generated)

**Format:** `pay_abc456def`

**When generated:** When user completes payment

**Purpose:**
- Razorpay's identifier for the actual payment
- Received in webhook
- Used for refunds (future feature)

**Received in webhook:**
```json
{
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_abc456def"
      }
    }
  }
}
```

---

## 💡 Payment Lifecycle (Detailed)

### State 1: `created`

**When:** `POST /payments` is called

**What happens:**
1. Frontend generates `idempotency_key`
2. Backend creates `Payment` record
3. `public_reference` is auto-generated
4. Status set to `created`

**Database state:**
```
payments:
  id: 1
  public_reference: PAY_ABC123
  idempotency_key: uuid-here
  amount: 499.00
  status: created
```

**Frontend receives:**
```json
{
  "success": true,
  "payment": { "id": 1, "public_reference": "PAY_ABC123" }
}
```

---

### State 2: `initiated`

**When:** `POST /payments/:id/create_order` is called

**What happens:**
1. Backend calls Razorpay API to create order
2. Razorpay returns `order_id`
3. Backend creates `PaymentAttempt` record
4. Payment status updated to `initiated`

**Database state:**
```
payments:
  id: 1
  status: initiated  # UPDATED

payment_attempts:
  id: 1
  payment_id: 1
  razorpay_order_id: order_xyz123
  status: created
  attempt_number: 1
  expires_at: 2024-01-01 00:15:00  # 15 mins from now
```

**Frontend receives:**
```json
{
  "success": true,
  "razorpay_order_id": "order_xyz123",
  "key_id": "rzp_test_...",
  "amount": 499.00
}
```

**Frontend action:**
```javascript
// Open Razorpay Checkout
const rzp = new Razorpay({
  key: response.key_id,
  order_id: response.razorpay_order_id,
  amount: response.amount * 100
});
rzp.open();
```

---

### State 3: `pending`

**When:** User opens Razorpay Checkout and starts entering card details

**What happens:**
1. Razorpay may send a webhook (optional, not all flows)
2. If webhook received, update to `pending`
3. This state is optional and may be skipped

**Note:** This state is not critical. Payment goes directly from `initiated` to `captured` in most cases.

---

### State 4: `captured` (SUCCESS ✓)

**When:** Razorpay sends `payment.captured` webhook

**What happens:**
1. Razorpay sends webhook to `POST /webhooks/razorpay`
2. Backend verifies webhook signature
3. Backend stores webhook in `webhook_events` table
4. Backend creates `GatewayTransaction` record
5. Backend updates `PaymentAttempt` status to `captured`
6. Backend updates `Payment` status to `captured`

**Webhook payload:**
```json
{
  "event": "payment.captured",
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_abc456",
        "order_id": "order_xyz123",
        "amount": 49900,  // in paise
        "currency": "INR",
        "status": "captured",
        "method": "card",
        "card": {
          "last4": "1234",
          "network": "Visa"
        },
        "email": "customer@example.com",
        "contact": "+919876543210",
        "fee": 990,  // Razorpay fee in paise
        "tax": 180   // Tax in paise
      }
    }
  }
}
```

**Database state:**
```
payments:
  id: 1
  status: captured  # UPDATED

payment_attempts:
  id: 1
  status: captured  # UPDATED

gateway_transactions:  # NEW RECORD
  id: 1
  payment_attempt_id: 1
  razorpay_payment_id: pay_abc456
  razorpay_order_id: order_xyz123
  amount: 499.00
  status: captured
  method: card
  card_last4: 1234
  card_network: Visa
  fee: 9.90
  tax: 1.80
  captured_at: 2024-01-01 00:05:00

webhook_events:  # NEW RECORD
  id: 1
  event_id: event_abc123
  event_type: payment.captured
  razorpay_payment_id: pay_abc456
  razorpay_order_id: order_xyz123
  payload: { ... }
  processed: true
  processed_at: 2024-01-01 00:05:01
```

**Frontend polling:**
```javascript
// Frontend polls GET /payments/PAY_ABC123
// Receives: { "payment": { "status": "captured" } }
// Shows success message
```

---

### State 5: `failed` (FAILURE ✗)

**When:** Razorpay sends `payment.failed` webhook

**What happens:**
1. Similar to `captured`, but with `failed` status
2. `error_code` and `error_description` are stored
3. Payment can be retried (user can try again)

**Webhook payload:**
```json
{
  "event": "payment.failed",
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_failed_123",
        "order_id": "order_xyz123",
        "status": "failed",
        "error_code": "BAD_REQUEST_ERROR",
        "error_description": "Payment failed due to insufficient funds"
      }
    }
  }
}
```

**Database state:**
```
payments:
  id: 1
  status: failed  # UPDATED

payment_attempts:
  id: 1
  status: failed  # UPDATED

gateway_transactions:
  id: 1
  razorpay_payment_id: pay_failed_123
  status: failed
  error_code: BAD_REQUEST_ERROR
  error_description: Payment failed due to insufficient funds
```

**Frontend action:**
```javascript
// Shows error message
// Offers "Retry Payment" button
// On retry, call POST /payments/:id/create_order again
// This creates a NEW payment_attempt with attempt_number: 2
```

---

## 🔄 Retry Flow

**Scenario:** User's first payment fails (insufficient funds), they add money and retry.

**Step 1:** First attempt fails
```
payment_attempts:
  id: 1
  payment_id: 1
  razorpay_order_id: order_first_123
  status: failed
  attempt_number: 1
```

**Step 2:** User clicks "Retry Payment"

**Step 3:** Frontend calls `POST /payments/:id/create_order` again

**Step 4:** Backend creates NEW Razorpay order and NEW attempt
```
payment_attempts:
  id: 1
  status: failed
  attempt_number: 1
  
  id: 2  # NEW ATTEMPT
  payment_id: 1  # SAME PAYMENT
  razorpay_order_id: order_second_456  # NEW ORDER
  status: created
  attempt_number: 2  # INCREMENTED
```

**Step 5:** User completes payment successfully

**Step 6:** Webhook updates second attempt to `captured`
```
payment_attempts:
  id: 2
  status: captured  # SUCCESS
  attempt_number: 2

payments:
  id: 1
  status: captured  # PAYMENT NOW SUCCESSFUL
```

**Why this design?**
- Complete audit trail of all attempts
- Can analyze why first attempt failed
- Can track retry success rate
- Razorpay orders expire after 15 mins, so need new order for retry

---

## 🛡️ Edge Cases Handled

### Edge Case 1: User Closes Browser After Payment

**Scenario:**
1. User completes payment in Razorpay Checkout
2. User closes browser before frontend callback executes
3. Frontend never receives success notification

**How we handle:**
- Webhook still arrives at backend
- Payment status updated to `captured`
- When user returns and opens app, frontend polls status
- Shows success message

**Code:**
```javascript
// On app load, check if there's a pending payment
const pendingPayment = localStorage.getItem('pending_payment_id');
if (pendingPayment) {
  checkPaymentStatus(pendingPayment);
}
```

---

### Edge Case 2: Duplicate Webhook

**Scenario:**
1. Razorpay sends `payment.captured` webhook
2. Network issue causes timeout
3. Razorpay retries and sends same webhook again

**How we handle:**
- `event_id` is unique for each webhook
- Database has UNIQUE constraint on `event_id`
- Second webhook attempt fails to insert (duplicate key error)
- We catch the error and return success (already processed)

**Code:**
```ruby
WebhookEvent.find_or_create_by(event_id: event_id) do |event|
  # ...
end
rescue ActiveRecord::RecordNotUnique
  # Already processed, return existing
  WebhookEvent.find_by(event_id: event_id)
end
```

---

### Edge Case 3: Webhook Arrives Before Frontend Callback

**Scenario:**
1. User completes payment
2. Webhook arrives at backend (fast server-to-server)
3. Frontend callback hasn't executed yet (slow network)

**How we handle:**
- Webhook updates payment status immediately
- When frontend callback executes, it polls for status
- Gets `captured` status immediately
- No race condition

---

### Edge Case 4: User Double-Clicks "Pay" Button

**Scenario:**
1. User clicks "Pay" button
2. Network is slow
3. User clicks "Pay" again (impatient)

**How we handle:**
- First click generates `idempotency_key` and stores in state
- Second click reuses SAME `idempotency_key`
- Backend returns existing payment (doesn't create duplicate)

**Frontend code:**
```javascript
let currentIdempotencyKey = null;

function handlePayClick() {
  if (!currentIdempotencyKey) {
    currentIdempotencyKey = uuidv4();
  }
  
  // Both clicks use same key
  createPayment(amount, currentIdempotencyKey);
}
```

---

### Edge Case 5: Razorpay Order Expires

**Scenario:**
1. User creates order (valid for 15 minutes)
2. User gets distracted, doesn't complete payment
3. Order expires

**How we handle:**
- `payment_attempts.expires_at` tracks expiry
- Can run a background job to mark expired attempts
- User can retry (creates new order)

**Background job:**
```ruby
# app/jobs/expire_old_attempts_job.rb
class ExpireOldAttemptsJob < ApplicationJob
  def perform
    PaymentAttempt.where('expires_at < ?', Time.current)
                  .where(status: ['created', 'pending'])
                  .update_all(status: 'expired')
  end
end
```

---

## 🔒 Security Best Practices

### 1. Webhook Signature Verification

**Why:** Prevent attackers from sending fake webhooks

**How:**
```ruby
expected_signature = OpenSSL::HMAC.hexdigest(
  OpenSSL::Digest.new('sha256'),
  RAZORPAY_WEBHOOK_SECRET,
  payload.to_json
)

# Use constant-time comparison to prevent timing attacks
ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
```

### 2. No Sensitive Data in Logs

**Bad:**
```ruby
Rails.logger.info "Payment: #{payment.inspect}"  # Might log sensitive data
```

**Good:**
```ruby
Rails.logger.info "Payment created: #{payment.public_reference}"
```

### 3. Environment Variables for Secrets

**Never hardcode:**
```ruby
# BAD
Razorpay.setup('rzp_test_abc123', 'secret_key_here')
```

**Always use ENV:**
```ruby
# GOOD
Razorpay.setup(ENV['RAZORPAY_KEY_ID'], ENV['RAZORPAY_KEY_SECRET'])
```

### 4. HTTPS Only in Production

**config/environments/production.rb:**
```ruby
config.force_ssl = true
```

---

## 📊 Monitoring & Alerts

### Key Metrics

1. **Payment Success Rate**
```sql
SELECT 
  DATE(created_at) as date,
  COUNT(*) as total,
  SUM(CASE WHEN status = 'captured' THEN 1 ELSE 0 END) as successful,
  ROUND(SUM(CASE WHEN status = 'captured' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as success_rate
FROM payments
WHERE created_at > NOW() - INTERVAL 30 DAY
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

2. **Unprocessed Webhooks**
```sql
SELECT COUNT(*) FROM webhook_events WHERE processed = FALSE;
```

3. **Average Payment Time**
```sql
SELECT 
  AVG(TIMESTAMPDIFF(SECOND, p.created_at, p.updated_at)) as avg_seconds
FROM payments p
WHERE p.status = 'captured'
AND p.created_at > NOW() - INTERVAL 24 HOUR;
```

### Alerts to Set Up

1. **Unprocessed webhooks > 10** → Alert ops team
2. **Success rate < 80%** → Investigate Razorpay issues
3. **Payment time > 5 minutes** → Check webhook delays
4. **Failed payments spike** → Check for Razorpay outage

---

## 🚀 Performance Optimization

### 1. Database Indexes

All critical indexes are already created in migrations:
- `payments.public_reference` (UNIQUE)
- `payments.idempotency_key` (UNIQUE)
- `payments.status`
- `payment_attempts.razorpay_order_id` (UNIQUE)
- `gateway_transactions.razorpay_payment_id` (UNIQUE)
- `webhook_events.event_id` (UNIQUE)

### 2. N+1 Query Prevention

**Bad:**
```ruby
payments = Payment.all
payments.each do |payment|
  puts payment.latest_attempt.razorpay_order_id  # N+1 query
end
```

**Good:**
```ruby
payments = Payment.includes(:payment_attempts).all
payments.each do |payment|
  puts payment.latest_attempt.razorpay_order_id  # No extra queries
end
```

### 3. Webhook Processing

**Current:** Synchronous (process immediately)

**For high traffic:** Use background jobs
```ruby
# In WebhooksController
def razorpay
  # Store webhook
  webhook_event = store_webhook_event
  
  # Process async
  ProcessWebhookJob.perform_later(webhook_event.id)
  
  render json: { success: true }, status: :ok
end
```

---

## 📝 Summary

This payment system is designed for **production use with real money**. Every decision prioritizes:

1. **Reliability** - Webhooks as source of truth
2. **Security** - No sensitive data, signature verification
3. **Idempotency** - Prevent duplicates at every level
4. **Auditability** - Complete trail of all events
5. **Scalability** - Optimized indexes, service objects

**You now have a complete, production-grade Razorpay integration!**
