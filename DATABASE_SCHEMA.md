# DATABASE SCHEMA DESIGN

## Overview
This schema is designed for high-reliability payment processing with complete audit trails.
NO DELETES - only state transitions. Every payment attempt is tracked.

---

## Table 1: `payments`
**Purpose**: Logical payment intent. One payment may have multiple attempts (retries).

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Internal identifier |
| `public_reference` | VARCHAR(64) | UNIQUE, NOT NULL, INDEX | User-visible payment ID (e.g., PAY_abc123xyz) |
| `idempotency_key` | VARCHAR(255) | UNIQUE, NOT NULL, INDEX | Frontend-generated UUID to prevent duplicate payments |
| `amount` | DECIMAL(10,2) | NOT NULL | Payment amount in INR (e.g., 499.00) |
| `currency` | VARCHAR(3) | NOT NULL, DEFAULT 'INR' | ISO currency code |
| `status` | ENUM | NOT NULL, INDEX | Current payment status (see lifecycle below) |
| `user_id` | BIGINT | NULLABLE, INDEX | Optional: link to users table if auth exists |
| `metadata` | JSON | NULLABLE | Additional data (product_id, user_email, etc.) |
| `created_at` | DATETIME | NOT NULL | When payment was initiated |
| `updated_at` | DATETIME | NOT NULL | Last status change |

**Status Values**: `created`, `initiated`, `pending`, `captured`, `failed`, `cancelled`

**Indexes**:
- PRIMARY KEY (`id`)
- UNIQUE INDEX (`public_reference`)
- UNIQUE INDEX (`idempotency_key`)
- INDEX (`status`, `created_at`) - for filtering/reporting
- INDEX (`user_id`) - if user tracking enabled

**Why this design?**
- `public_reference`: Safe to show in frontend URLs, emails, support tickets
- `idempotency_key`: Prevents user double-clicks from creating duplicate payments
- `status`: Quick filtering for dashboards, reconciliation
- `metadata`: Flexible storage without schema changes

---

## Table 2: `payment_attempts`
**Purpose**: Each Razorpay order creation is an attempt. A payment may have multiple attempts if user retries.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Internal identifier |
| `payment_id` | BIGINT | NOT NULL, FOREIGN KEY, INDEX | Links to `payments.id` |
| `razorpay_order_id` | VARCHAR(255) | UNIQUE, NOT NULL, INDEX | Razorpay's order_id (e.g., order_xyz123) |
| `amount` | DECIMAL(10,2) | NOT NULL | Amount for this attempt (should match payment.amount) |
| `currency` | VARCHAR(3) | NOT NULL, DEFAULT 'INR' | Currency for this attempt |
| `status` | ENUM | NOT NULL, INDEX | Attempt status |
| `razorpay_order_status` | VARCHAR(50) | NULLABLE | Raw status from Razorpay |
| `attempt_number` | INT | NOT NULL, DEFAULT 1 | Retry counter (1, 2, 3...) |
| `expires_at` | DATETIME | NULLABLE | When Razorpay order expires |
| `created_at` | DATETIME | NOT NULL | When order was created |
| `updated_at` | DATETIME | NOT NULL | Last update |

**Status Values**: `created`, `pending`, `authorized`, `captured`, `failed`, `expired`

**Indexes**:
- PRIMARY KEY (`id`)
- FOREIGN KEY (`payment_id`) REFERENCES `payments(id)`
- UNIQUE INDEX (`razorpay_order_id`)
- INDEX (`payment_id`, `attempt_number`) - for fetching latest attempt
- INDEX (`status`)

**Why this design?**
- `razorpay_order_id`: The order ID returned by Razorpay, used in checkout
- `attempt_number`: Track retries (user abandoned first attempt, tried again)
- `expires_at`: Razorpay orders expire after ~15 minutes
- Separation from `payments`: One logical payment can have multiple Razorpay orders

---

## Table 3: `gateway_transactions`
**Purpose**: Maps Razorpay payment_id to our system. One attempt may have multiple transactions (rare, but possible with authorization flows).

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Internal identifier |
| `payment_attempt_id` | BIGINT | NOT NULL, FOREIGN KEY, INDEX | Links to `payment_attempts.id` |
| `razorpay_payment_id` | VARCHAR(255) | UNIQUE, NOT NULL, INDEX | Razorpay's payment_id (e.g., pay_abc123) |
| `razorpay_order_id` | VARCHAR(255) | NOT NULL, INDEX | Razorpay's order_id (for cross-reference) |
| `amount` | DECIMAL(10,2) | NOT NULL | Actual amount processed by Razorpay |
| `currency` | VARCHAR(3) | NOT NULL | Currency |
| `status` | VARCHAR(50) | NOT NULL, INDEX | Razorpay payment status (captured, failed, etc.) |
| `method` | VARCHAR(50) | NULLABLE | Payment method (card, netbanking, upi, wallet) |
| `card_last4` | VARCHAR(4) | NULLABLE | Last 4 digits of card (if card payment) |
| `card_network` | VARCHAR(20) | NULLABLE | Visa, Mastercard, etc. |
| `bank` | VARCHAR(100) | NULLABLE | Bank name (if netbanking/UPI) |
| `email` | VARCHAR(255) | NULLABLE | Customer email from Razorpay |
| `contact` | VARCHAR(15) | NULLABLE | Customer phone from Razorpay |
| `fee` | DECIMAL(10,2) | NULLABLE | Razorpay fee (if available in webhook) |
| `tax` | DECIMAL(10,2) | NULLABLE | Tax on fee |
| `error_code` | VARCHAR(100) | NULLABLE | Razorpay error code (if failed) |
| `error_description` | TEXT | NULLABLE | Human-readable error |
| `captured_at` | DATETIME | NULLABLE | When payment was captured |
| `created_at` | DATETIME | NOT NULL | When transaction record was created |
| `updated_at` | DATETIME | NOT NULL | Last update |

**Indexes**:
- PRIMARY KEY (`id`)
- FOREIGN KEY (`payment_attempt_id`) REFERENCES `payment_attempts(id)`
- UNIQUE INDEX (`razorpay_payment_id`)
- INDEX (`razorpay_order_id`)
- INDEX (`status`)
- INDEX (`created_at`) - for reporting

**Why this design?**
- `razorpay_payment_id`: The actual payment ID from Razorpay (received in webhook)
- `method`, `card_last4`, etc.: For customer support, reconciliation, analytics
- `fee`, `tax`: For accounting and settlement reconciliation
- `error_code`: Critical for debugging failed payments
- NO sensitive data (CVV, full card number) - PCI compliance

---

## Table 4: `webhook_events`
**Purpose**: Store ALL incoming webhooks for audit, replay, and idempotency.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Internal identifier |
| `event_id` | VARCHAR(255) | UNIQUE, NOT NULL, INDEX | Razorpay's event ID (e.g., event_xyz123) |
| `event_type` | VARCHAR(100) | NOT NULL, INDEX | Event type (payment.captured, payment.failed, etc.) |
| `razorpay_payment_id` | VARCHAR(255) | NULLABLE, INDEX | Payment ID from webhook payload |
| `razorpay_order_id` | VARCHAR(255) | NULLABLE, INDEX | Order ID from webhook payload |
| `payload` | JSON | NOT NULL | Full webhook payload (for audit/replay) |
| `signature` | VARCHAR(255) | NOT NULL | Razorpay signature (for verification) |
| `processed` | BOOLEAN | NOT NULL, DEFAULT FALSE, INDEX | Whether we've processed this event |
| `processed_at` | DATETIME | NULLABLE | When we processed it |
| `processing_error` | TEXT | NULLABLE | Error message if processing failed |
| `created_at` | DATETIME | NOT NULL, INDEX | When webhook was received |

**Indexes**:
- PRIMARY KEY (`id`)
- UNIQUE INDEX (`event_id`) - **CRITICAL for idempotency**
- INDEX (`event_type`)
- INDEX (`razorpay_payment_id`)
- INDEX (`razorpay_order_id`)
- INDEX (`processed`, `created_at`) - for finding unprocessed events
- INDEX (`created_at`) - for cleanup jobs

**Why this design?**
- `event_id`: Razorpay sends unique event IDs - prevents duplicate processing
- `payload`: Store everything for audit, debugging, replay
- `processed`: Allows async processing (receive webhook → process later)
- `processing_error`: Track failures without losing the event
- **Idempotency**: UNIQUE constraint on `event_id` prevents duplicate processing

---

## Relationships

```
payments (1) ──────< (many) payment_attempts
                              │
                              │
                              └──< (many) gateway_transactions
                              
webhook_events ──(references)──> gateway_transactions (via razorpay_payment_id)
```

---

## State Transition Rules

### Payment States
```
created → initiated → pending → captured ✓
                              → failed ✗
                              → cancelled ✗
```

### Payment Attempt States
```
created → pending → authorized → captured ✓
                  → failed ✗
                  → expired ✗
```

### Gateway Transaction States
```
created → authorized → captured ✓
        → failed ✗
```

---

## Data Retention & Compliance

1. **Never delete payment records** - Required for accounting, tax, audits
2. **Keep webhook events for 90 days** - Then archive to cold storage
3. **No PCI data** - Never store CVV, full card numbers, OTP
4. **Encrypt metadata** - If storing user emails, phone numbers (optional)
5. **Audit logs** - All state changes should be logged (use Rails callbacks)

---

## Indexes Strategy

**Why these specific indexes?**

1. **Unique indexes** - Enforce business rules at DB level (idempotency)
2. **Foreign key indexes** - Speed up joins and cascade operations
3. **Status + timestamp** - Common query pattern for dashboards
4. **Composite indexes** - `(payment_id, attempt_number)` for "latest attempt" queries

**Performance considerations**:
- All indexes are on columns used in WHERE, JOIN, ORDER BY clauses
- Avoid over-indexing (each index slows down writes)
- Monitor slow queries and add indexes as needed

---

## Example Queries

```sql
-- Find payment by public reference
SELECT * FROM payments WHERE public_reference = 'PAY_abc123';

-- Get latest attempt for a payment
SELECT * FROM payment_attempts 
WHERE payment_id = 123 
ORDER BY attempt_number DESC 
LIMIT 1;

-- Find transaction by Razorpay payment ID
SELECT * FROM gateway_transactions 
WHERE razorpay_payment_id = 'pay_xyz123';

-- Unprocessed webhooks
SELECT * FROM webhook_events 
WHERE processed = FALSE 
ORDER BY created_at ASC;

-- Failed payments in last 24 hours
SELECT * FROM payments 
WHERE status = 'failed' 
AND created_at > NOW() - INTERVAL 24 HOUR;
```

---

## Migration Order

1. Create `payments` table
2. Create `payment_attempts` table (depends on payments)
3. Create `gateway_transactions` table (depends on payment_attempts)
4. Create `webhook_events` table (independent)

