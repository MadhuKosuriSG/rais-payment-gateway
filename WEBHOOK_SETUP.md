# 🔗 Razorpay Webhook Configuration Guide

## 📍 Your Webhook URL

### **For Staging (payment.applyuninow.com):**

**HTTP (Not Recommended):**
```
http://payment.applyuninow.com:3005/webhooks/razorpay
```

**HTTPS (Recommended):**
```
https://payment.applyuninow.com/webhooks/razorpay
```

> ⚠️ **Important:** Razorpay **requires HTTPS** for webhooks in production/live mode. HTTP only works in test mode.

---

## ✅ **Does HTTP Work?**

### **Test Mode (rzp_test_...):**
- ✅ **YES** - HTTP webhooks work
- You can use: `http://payment.applyuninow.com:3005/webhooks/razorpay`

### **Live Mode (rzp_live_...):**
- ❌ **NO** - HTTPS is required
- You must use: `https://payment.applyuninow.com/webhooks/razorpay`

---

## 🔧 **Setup Steps**

### **Step 1: Configure Razorpay Webhook**

1. Go to: https://dashboard.razorpay.com/app/webhooks
2. Click **"Create Webhook"**
3. Enter webhook URL:
   ```
   http://payment.applyuninow.com:3005/webhooks/razorpay
   ```
   *(Use HTTPS if you have SSL certificate)*

4. **Select Events:**
   - ✅ `payment.authorized`
   - ✅ `payment.captured`
   - ✅ `payment.failed`

5. **Active:** Yes
6. Click **"Create Webhook"**
7. **Copy the Webhook Secret**

---

### **Step 2: Update .env File**

Add the webhook secret to your `.env` file:

```env
RAZORPAY_WEBHOOK_SECRET=whsec_your_actual_secret_here
```

---

### **Step 3: Restart Rails Server**

```bash
# Stop current server (Ctrl+C)
# Then restart
rails s -p 3005
```

---

## 🧪 **Test Your Webhook**

### **Method 1: Using cURL**

```bash
curl -X POST http://payment.applyuninow.com:3005/webhooks/razorpay \
  -H "Content-Type: application/json" \
  -H "X-Razorpay-Event-Id: test_event_123" \
  -H "X-Razorpay-Signature: test_signature" \
  -d '{
    "event": "payment.captured",
    "payload": {
      "payment": {
        "entity": {
          "id": "pay_test123",
          "order_id": "order_test123",
          "amount": 49900,
          "currency": "INR",
          "status": "captured",
          "method": "card"
        }
      }
    }
  }'
```

### **Method 2: Make a Real Payment**

1. Create a payment using your frontend
2. Complete the payment with test card: `4111 1111 1111 1111`
3. Check Rails logs to see webhook received:
   ```bash
   tail -f log/development.log
   ```

---

## 🔐 **SSL/HTTPS Setup (For Production)**

If you need HTTPS for live mode, you have two options:

### **Option 1: Use Nginx with SSL**

```nginx
server {
    listen 443 ssl;
    server_name payment.applyuninow.com;

    ssl_certificate /path/to/ssl/certificate.crt;
    ssl_certificate_key /path/to/ssl/private.key;

    location / {
        proxy_pass http://localhost:3005;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### **Option 2: Use Cloudflare or Similar CDN**

1. Point your domain to Cloudflare
2. Enable SSL/TLS (Full or Flexible)
3. Cloudflare will handle HTTPS
4. Your Rails app can still use HTTP internally

---

## 📊 **Verify Webhook Configuration**

### **Check if Webhook is Configured:**

1. Go to: https://dashboard.razorpay.com/app/webhooks
2. You should see your webhook listed
3. Status should be **Active**

### **Check Rails Logs:**

```bash
# Watch logs in real-time
tail -f log/development.log

# Or for staging
tail -f log/staging.log
```

When a webhook is received, you'll see:
```
Received webhook: payment.captured (evt_xyz123)
Webhook processed successfully: evt_xyz123
```

---

## 🐛 **Troubleshooting**

### **Issue 1: "Blocked host" error**

**Solution:** Already fixed! The host is now allowed in:
- `config/environments/development.rb`
- `config/environments/staging.rb`

### **Issue 2: Webhook signature verification fails**

**Solution:**
1. Verify `RAZORPAY_WEBHOOK_SECRET` in `.env` matches Razorpay dashboard
2. Restart Rails server after updating `.env`

### **Issue 3: Webhook not received**

**Solution:**
1. Check if Rails server is running: `http://payment.applyuninow.com:3005/health`
2. Check firewall settings - port 3005 must be open
3. Verify webhook URL in Razorpay dashboard is correct
4. Check Rails logs for errors

### **Issue 4: HTTPS required error (Live mode)**

**Solution:**
- Set up SSL certificate (Let's Encrypt, Cloudflare, etc.)
- Or use test mode for development

---

## 📝 **Environment-Specific URLs**

| Environment | URL | SSL Required | Port |
|-------------|-----|--------------|------|
| **Local (ngrok)** | `https://abc123.ngrok.io/webhooks/razorpay` | ✅ Yes (ngrok provides) | Any |
| **Staging (HTTP)** | `http://payment.applyuninow.com:3005/webhooks/razorpay` | ❌ No (test mode) | 3005 |
| **Staging (HTTPS)** | `https://payment.applyuninow.com/webhooks/razorpay` | ✅ Yes | 443 |
| **Production** | `https://payment.applyuninow.com/webhooks/razorpay` | ✅ Yes (required) | 443 |

---

## 🎯 **Quick Reference**

### **Your Current Setup:**

- **Domain:** `payment.applyuninow.com`
- **Port:** `3005`
- **Webhook Endpoint:** `/webhooks/razorpay`
- **Full URL (HTTP):** `http://payment.applyuninow.com:3005/webhooks/razorpay`

### **Razorpay Credentials:**

```env
RAZORPAY_KEY_ID=rzp_test_SCNon27YdwiJYi
RAZORPAY_KEY_SECRET=ZaMak8CTRaXDqXBpAU0eR6hT
RAZORPAY_WEBHOOK_SECRET=<copy from dashboard>
```

---

## ✅ **Next Steps:**

1. ✅ Host configuration - **DONE**
2. ⏳ Configure webhook in Razorpay dashboard
3. ⏳ Copy webhook secret to `.env`
4. ⏳ Restart Rails server
5. ⏳ Test with a payment

---

**Need Help?**

Check webhook events in database:
```bash
rails console
WebhookEvent.order(created_at: :desc).limit(10)
```
