# ⚡ QUICK START GUIDE

Get your Razorpay payment system running in **5 minutes**!

---

## 📋 Prerequisites Checklist

- [ ] Ruby 3.0+ installed (`ruby -v`)
- [ ] Rails 7.0+ installed (`rails -v`)
- [ ] MySQL 8.0+ installed and running
- [ ] Razorpay account ([Sign up](https://dashboard.razorpay.com/signup))

---

## 🚀 5-Minute Setup

### Step 1: Install Dependencies (1 min)

```bash
cd /Users/madhukosuri/learning/rais-payment-gateway
bundle install
```

### Step 2: Configure Environment (1 min)

```bash
# Copy example env file
cp .env.example .env

# Edit .env file
nano .env
```

**Add your Razorpay credentials:**

```env
RAZORPAY_KEY_ID=rzp_test_your_key_id_here
RAZORPAY_KEY_SECRET=your_secret_here
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret_here
DATABASE_PASSWORD=your_mysql_password
```

**Get Razorpay credentials:**
1. Login to [Razorpay Dashboard](https://dashboard.razorpay.com/)
2. Go to Settings → API Keys
3. Copy **Key ID** and **Key Secret**
4. For webhook secret: Settings → Webhooks → Create Webhook

### Step 3: Setup Database (2 min)

```bash
# Create database
rails db:create

# Run migrations
rails db:migrate
```

**Expected output:**
```
== 20260204000001 CreatePayments: migrating ===================================
-- create_table(:payments)
   -> 0.0234s
== 20260204000001 CreatePayments: migrated (0.0235s) ==========================

== 20260204000002 CreatePaymentAttempts: migrating ============================
-- create_table(:payment_attempts)
   -> 0.0189s
== 20260204000002 CreatePaymentAttempts: migrated (0.0190s) ===================

== 20260204000003 CreateGatewayTransactions: migrating ========================
-- create_table(:gateway_transactions)
   -> 0.0245s
== 20260204000003 CreateGatewayTransactions: migrated (0.0246s) ===============

== 20260204000004 CreateWebhookEvents: migrating ==============================
-- create_table(:webhook_events)
   -> 0.0198s
== 20260204000004 CreateWebhookEvents: migrated (0.0199s) =====================
```

### Step 4: Start Server (30 sec)

```bash
rails server
```

**Server should start on:** `http://localhost:3000`

### Step 5: Test It! (30 sec)

**Open in browser:**
```
http://localhost:3000/payment_demo.html
```

**Or test with cURL:**

```bash
# Create payment
curl -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 499.00,
    "idempotency_key": "test-uuid-123",
    "metadata": {
      "product_id": 1,
      "user_email": "test@example.com"
    }
  }'
```

**Expected response:**
```json
{
  "success": true,
  "payment": {
    "id": 1,
    "public_reference": "PAY_ABC123XYZ",
    "amount": 499.0,
    "currency": "INR",
    "status": "created"
  }
}
```

---

## ✅ Verify Installation

Run these commands to verify everything is working:

```bash
# 1. Check health endpoint
curl http://localhost:3000/health
# Expected: OK

# 2. Check API docs
curl http://localhost:3000/api/docs
# Expected: JSON with endpoint list

# 3. Check database tables
rails dbconsole
> SHOW TABLES;
# Expected: payments, payment_attempts, gateway_transactions, webhook_events

# 4. Check Razorpay configuration
rails console
> ENV['RAZORPAY_KEY_ID']
# Expected: Your Razorpay key ID
```

---

## 🧪 Test Payment Flow

### Option 1: Using the Demo Page

1. Open `http://localhost:3000/payment_demo.html`
2. Enter email and phone
3. Click "Pay ₹499.00"
4. Use test card: `4111 1111 1111 1111`
5. Any future expiry, any CVV
6. Complete payment
7. See success message!

### Option 2: Using cURL

```bash
# Step 1: Create payment
PAYMENT_RESPONSE=$(curl -s -X POST http://localhost:3000/payments \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 499.00,
    "idempotency_key": "test-'$(date +%s)'",
    "metadata": {"product_id": 1}
  }')

echo $PAYMENT_RESPONSE

# Extract payment ID
PAYMENT_ID=$(echo $PAYMENT_RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

# Step 2: Create Razorpay order
ORDER_RESPONSE=$(curl -s -X POST http://localhost:3000/payments/$PAYMENT_ID/create_order)

echo $ORDER_RESPONSE

# Step 3: Check payment status
curl http://localhost:3000/payments/$PAYMENT_ID
```

---

## 🔧 Troubleshooting

### Issue: "Bundle install fails"

**Solution:**
```bash
# Update bundler
gem install bundler

# Try again
bundle install
```

### Issue: "Database connection failed"

**Solution:**
```bash
# Check MySQL is running
mysql.server status

# Start MySQL if not running
mysql.server start

# Verify credentials in .env
nano .env
```

### Issue: "Razorpay key not found"

**Solution:**
1. Verify `.env` file exists
2. Check credentials are correct
3. Restart Rails server after editing `.env`

### Issue: "Migrations fail"

**Solution:**
```bash
# Drop and recreate database
rails db:drop
rails db:create
rails db:migrate
```

---

## 📚 Next Steps

Now that your system is running:

1. **Read the docs:**
   - [README.md](README.md) - Complete API documentation
   - [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Deep dive into architecture
   - [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) - Database design details

2. **Configure webhooks:**
   - Go to [Razorpay Webhooks](https://dashboard.razorpay.com/app/webhooks)
   - Add webhook URL: `https://your-domain.com/webhooks/razorpay`
   - Subscribe to: `payment.captured`, `payment.failed`

3. **Test thoroughly:**
   - Test successful payments
   - Test failed payments (use card `4000 0000 0000 0002`)
   - Test retries
   - Test webhook handling

4. **Deploy to production:**
   - Update `.env` with live Razorpay credentials
   - Enable SSL (`config.force_ssl = true`)
   - Set up monitoring and alerts
   - Configure webhook URL with your production domain

---

## 🎯 Common Commands

```bash
# Start server
rails server

# Run console
rails console

# Check routes
rails routes

# Run migrations
rails db:migrate

# Reset database (WARNING: Deletes all data)
rails db:reset

# Check logs
tail -f log/development.log

# Open database console
rails dbconsole
```

---

## 📞 Need Help?

- **Razorpay docs:** https://razorpay.com/docs/
- **Rails guides:** https://guides.rubyonrails.org/
- **Check logs:** `tail -f log/development.log`

---

**You're all set! 🎉**

Your production-grade Razorpay payment system is ready to handle real money transactions!
