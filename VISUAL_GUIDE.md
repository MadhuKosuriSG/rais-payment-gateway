# 🎨 VISUAL SYSTEM OVERVIEW

## Complete Production-Grade Razorpay Payment System

---

## 📊 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FRONTEND (React/HTML)                         │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │ Generate UUID│  │ Create       │  │ Open Razorpay│                 │
│  │ (idempotency)│→ │ Payment      │→ │ Checkout     │                 │
│  └──────────────┘  └──────────────┘  └──────────────┘                 │
│         │                  │                  │                         │
└─────────┼──────────────────┼──────────────────┼─────────────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      RAILS API BACKEND                                  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    CONTROLLERS                                  │   │
│  │  ┌──────────────────┐         ┌──────────────────┐            │   │
│  │  │ PaymentsController│         │WebhooksController│            │   │
│  │  │                  │         │                  │            │   │
│  │  │ • create         │         │ • razorpay       │            │   │
│  │  │ • create_order   │         │                  │            │   │
│  │  │ • show           │         │                  │            │   │
│  │  └────────┬─────────┘         └────────┬─────────┘            │   │
│  └───────────┼──────────────────────────────┼──────────────────────┘   │
│              │                              │                          │
│              ▼                              ▼                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      SERVICES                                   │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │   │
│  │  │Payments::        │  │Payments::        │  │Webhooks::    │ │   │
│  │  │CreateService     │  │CreateOrderService│  │ProcessService│ │   │
│  │  │                  │  │                  │  │              │ │   │
│  │  │• Idempotency     │  │• Razorpay API    │  │• Signature   │ │   │
│  │  │• Validation      │  │• Order creation  │  │• Idempotency │ │   │
│  │  │• Payment creation│  │• Attempt tracking│  │• Status update│ │   │
│  │  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘ │   │
│  └───────────┼──────────────────────┼────────────────────┼─────────┘   │
│              │                      │                    │             │
│              ▼                      ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                       MODELS                                    │   │
│  │  ┌──────────┐  ┌──────────────┐  ┌─────────────┐  ┌──────────┐│   │
│  │  │ Payment  │  │PaymentAttempt│  │Gateway      │  │Webhook   ││   │
│  │  │          │  │              │  │Transaction  │  │Event     ││   │
│  │  │• Status  │  │• Retry count │  │• Razorpay   │  │• Payload ││   │
│  │  │• Amount  │  │• Order ID    │  │  payment ID │  │• Processed││   │
│  │  │• Public  │  │• Expires at  │  │• Method     │  │• Event ID││   │
│  │  │  ref     │  │              │  │• Fees       │  │          ││   │
│  │  └────┬─────┘  └──────┬───────┘  └──────┬──────┘  └────┬─────┘│   │
│  └───────┼────────────────┼─────────────────┼──────────────┼──────┘   │
│          │                │                 │              │          │
└──────────┼────────────────┼─────────────────┼──────────────┼──────────┘
           │                │                 │              │
           ▼                ▼                 ▼              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         MYSQL DATABASE                                  │
│                                                                         │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────────────┐ │
│  │  payments    │  │ payment_attempts │  │ gateway_transactions     │ │
│  │              │  │                  │  │                          │ │
│  │ • id         │  │ • id             │  │ • id                     │ │
│  │ • public_ref │  │ • payment_id (FK)│  │ • payment_attempt_id (FK)│ │
│  │ • idempotency│  │ • razorpay_order │  │ • razorpay_payment_id    │ │
│  │ • amount     │  │ • attempt_number │  │ • method                 │ │
│  │ • status     │  │ • status         │  │ • card_last4             │ │
│  │ • metadata   │  │ • expires_at     │  │ • fee, tax               │ │
│  └──────────────┘  └──────────────────┘  └──────────────────────────┘ │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                     webhook_events                               │  │
│  │                                                                  │  │
│  │ • id                                                             │  │
│  │ • event_id (UNIQUE) ← Idempotency key                          │  │
│  │ • event_type                                                     │  │
│  │ • payload (JSON)                                                 │  │
│  │ • processed (BOOLEAN)                                            │  │
│  │ • signature                                                      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
           ▲
           │
           │ Webhooks (payment.captured, payment.failed)
           │
┌──────────┴──────────┐
│                     │
│  RAZORPAY GATEWAY   │
│                     │
│  • Order creation   │
│  • Payment processing│
│  • Webhook sending  │
│                     │
└─────────────────────┘
```

---

## 🔄 Payment State Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PAYMENT STATE MACHINE                        │
└─────────────────────────────────────────────────────────────────┘

    ┌─────────┐
    │ created │  ← POST /payments (idempotency_key + amount)
    └────┬────┘
         │
         │ POST /payments/:id/create_order
         │ (Razorpay order created)
         ▼
    ┌──────────┐
    │initiated │
    └────┬─────┘
         │
         │ User opens Razorpay Checkout
         ▼
    ┌─────────┐
    │ pending │  (Optional state)
    └────┬────┘
         │
         ├──────────────┬──────────────┐
         │              │              │
         ▼              ▼              ▼
    ┌─────────┐    ┌────────┐    ┌──────────┐
    │captured │    │ failed │    │cancelled │
    │   ✓     │    │   ✗    │    │    ✗     │
    └─────────┘    └───┬────┘    └──────────┘
                       │
                       │ User can retry
                       ▼
                  ┌──────────┐
                  │initiated │  (New attempt created)
                  └──────────┘
```

---

## 📁 File Organization

```
rais-payment-gateway/
│
├── 📚 DOCUMENTATION (8 files - 90 KB)
│   ├── README.md                    ⭐ Start here - Complete guide
│   ├── QUICK_START.md               ⚡ 5-minute setup
│   ├── IMPLEMENTATION_GUIDE.md      🧠 Deep dive
│   ├── DATABASE_SCHEMA.md           🗄️ Database design
│   ├── TESTING_GUIDE.md             🧪 Test scenarios
│   ├── PROJECT_SUMMARY.md           📊 Overview
│   ├── DOCUMENTATION_INDEX.md       🗺️ Navigation
│   └── DELIVERY_SUMMARY.md          ✅ What's delivered
│
├── 🗄️ DATABASE (4 migrations)
│   ├── 20260204000001_create_payments.rb
│   ├── 20260204000002_create_payment_attempts.rb
│   ├── 20260204000003_create_gateway_transactions.rb
│   └── 20260204000004_create_webhook_events.rb
│
├── 📦 MODELS (4 files)
│   ├── payment.rb                   💰 Main payment
│   ├── payment_attempt.rb           🔄 Retry tracking
│   ├── gateway_transaction.rb       💳 Razorpay details
│   └── webhook_event.rb             📨 Webhook storage
│
├── 🎮 CONTROLLERS (2 files)
│   ├── payments_controller.rb       🔌 3 endpoints
│   └── webhooks_controller.rb       📡 Webhook receiver
│
├── 🔧 SERVICES (3 files)
│   ├── payments/create_service.rb        🆕 Create payment
│   ├── payments/create_order_service.rb  📝 Create order
│   └── webhooks/process_service.rb       ⚙️ Process webhooks
│
├── ⚙️ CONFIGURATION (3 files)
│   ├── initializers/razorpay.rb     🔑 Razorpay setup
│   ├── initializers/cors.rb         🌐 CORS config
│   └── routes.rb                    🛣️ API routes
│
└── 🎨 FRONTEND (1 file)
    └── public/payment_demo.html     🖥️ Working demo
```

---

## 🔌 API Endpoint Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        API ENDPOINTS                            │
└─────────────────────────────────────────────────────────────────┘

POST /payments
├── Input: { amount, idempotency_key, metadata }
├── Output: { payment: { id, public_reference, status } }
└── Purpose: Create payment with idempotency

POST /payments/:id/create_order
├── Input: Payment ID (from previous step)
├── Output: { razorpay_order_id, key_id, amount }
└── Purpose: Create Razorpay order for checkout

GET /payments/:id
├── Input: Payment ID or public_reference
├── Output: { payment: { status, attempts, transactions } }
└── Purpose: Check payment status (polling)

POST /webhooks/razorpay
├── Input: Razorpay webhook payload
├── Headers: X-Razorpay-Event-Id, X-Razorpay-Signature
├── Output: { success: true }
└── Purpose: Receive payment status updates

GET /health
├── Output: OK
└── Purpose: Health check

GET /api/docs
├── Output: { endpoints: {...} }
└── Purpose: API documentation
```

---

## 🔐 Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                      SECURITY LAYERS                            │
└─────────────────────────────────────────────────────────────────┘

Layer 1: IDEMPOTENCY
├── Frontend generates UUID
├── Database UNIQUE constraint on idempotency_key
└── Prevents duplicate payments

Layer 2: WEBHOOK SIGNATURE VERIFICATION
├── HMAC SHA256 signature
├── Constant-time comparison
└── Prevents fake webhooks

Layer 3: DATA PROTECTION
├── No CVV storage
├── No full card numbers
├── Only last 4 digits
└── PCI DSS compliant

Layer 4: CORS
├── Restricted origins for payments
├── Open for webhooks (Razorpay servers)
└── Environment-based configuration

Layer 5: ENVIRONMENT VARIABLES
├── No hardcoded secrets
├── .env file for credentials
└── Different configs per environment
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                       DATA FLOW                                 │
└─────────────────────────────────────────────────────────────────┘

1. CREATE PAYMENT
   Frontend → POST /payments → CreateService → Payment (DB)
   
2. CREATE ORDER
   Frontend → POST /payments/:id/create_order → CreateOrderService
   → Razorpay API → PaymentAttempt (DB)
   
3. USER PAYS
   Frontend → Razorpay Checkout → User enters card → Razorpay Gateway
   
4. WEBHOOK (SOURCE OF TRUTH)
   Razorpay → POST /webhooks/razorpay → ProcessService
   → WebhookEvent (DB) → GatewayTransaction (DB)
   → PaymentAttempt.status = captured
   → Payment.status = captured
   
5. FRONTEND POLLS
   Frontend → GET /payments/:id → Payment (DB) → status: captured
```

---

## 🎯 Key Identifiers Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  IDENTIFIER GENERATION                          │
└─────────────────────────────────────────────────────────────────┘

idempotency_key (UUID)
├── Generated by: Frontend
├── Used for: Preventing duplicate payments
├── Stored in: payments.idempotency_key
└── Example: "550e8400-e29b-41d4-a716-446655440000"

public_reference
├── Generated by: Backend (Payment model)
├── Used for: User-visible payment ID
├── Stored in: payments.public_reference
└── Example: "PAY_ABC123XYZ"

razorpay_order_id
├── Generated by: Razorpay API
├── Used for: Razorpay Checkout
├── Stored in: payment_attempts.razorpay_order_id
└── Example: "order_xyz123abc"

razorpay_payment_id
├── Generated by: Razorpay (when user pays)
├── Used for: Actual payment reference
├── Stored in: gateway_transactions.razorpay_payment_id
└── Example: "pay_abc456def"

event_id
├── Generated by: Razorpay (webhook)
├── Used for: Webhook idempotency
├── Stored in: webhook_events.event_id
└── Example: "event_xyz789ghi"
```

---

## 📈 Performance Optimization

```
┌─────────────────────────────────────────────────────────────────┐
│                  PERFORMANCE FEATURES                           │
└─────────────────────────────────────────────────────────────────┘

DATABASE INDEXES
├── Unique indexes (idempotency, order_id, payment_id, event_id)
├── Foreign key indexes (all FK columns)
├── Status indexes (for filtering)
└── Composite indexes (status + created_at)

QUERY OPTIMIZATION
├── Eager loading (includes/joins)
├── Scopes for common queries
├── Indexed columns in WHERE clauses
└── Efficient pagination ready

API DESIGN
├── Stateless (horizontal scaling ready)
├── Service objects (clean separation)
├── JSON responses (fast serialization)
└── Minimal data transfer

CACHING READY
├── Payment status can be cached
├── Razorpay key_id can be cached
└── Static data cacheable
```

---

## 🧪 Test Coverage Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     TEST SCENARIOS                              │
└─────────────────────────────────────────────────────────────────┘

✅ Scenario 1: Successful Payment
   └── Create → Order → Pay → Webhook → Captured

✅ Scenario 2: Failed Payment
   └── Create → Order → Pay (fail) → Webhook → Failed

✅ Scenario 3: Payment Retry
   └── Failed → Retry → New Order → Pay → Captured

✅ Scenario 4: Idempotency
   └── Create → Create (same key) → Same payment returned

✅ Scenario 5: Webhook Signature
   └── Invalid signature → Rejected

✅ Scenario 6: Duplicate Webhook
   └── Webhook → Same webhook → Idempotent (no duplicate)

✅ Edge Cases
   ├── Browser close after payment
   ├── Webhook before frontend callback
   ├── Double-click prevention
   └── Order expiry
```

---

## 🚀 Deployment Checklist

```
┌─────────────────────────────────────────────────────────────────┐
│                  PRODUCTION DEPLOYMENT                          │
└─────────────────────────────────────────────────────────────────┘

BEFORE DEPLOYMENT
├── ✅ Update .env with live credentials
├── ✅ Configure Razorpay webhook URL
├── ✅ Enable SSL (config.force_ssl = true)
├── ✅ Set up database backups
├── ✅ Configure monitoring
├── ✅ Test with Razorpay test mode
├── ✅ Review security settings
└── ✅ Set up error tracking

AFTER DEPLOYMENT
├── ✅ Verify webhook endpoint accessible
├── ✅ Test live payment (small amount)
├── ✅ Monitor webhook processing
├── ✅ Check database performance
└── ✅ Set up alerts
```

---

**🎉 COMPLETE PRODUCTION-READY SYSTEM!**

*Visual guide created: February 4, 2026*
