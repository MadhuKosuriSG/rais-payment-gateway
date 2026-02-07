# Staging Environment Setup Guide

## 🔧 Database Configuration Changes

The `config/database.yml` has been updated to support staging environment with the following improvements:

### Key Changes:

1. **Environment Variable Support**: All database credentials now use environment variables
2. **TCP/IP Connection**: Staging and production use TCP/IP instead of socket connections
3. **Connection Timeouts**: Added timeout settings for better reliability
4. **Flexible Configuration**: Can switch between socket and TCP/IP based on environment

---

## 📋 Setting Up Staging Environment

### Step 1: Create Staging Environment File

Copy the example file and update with your actual credentials:

```bash
cp .env.staging.example .env.staging
```

### Step 2: Update `.env.staging` with Your Credentials

Edit `.env.staging` and replace the placeholder values:

```env
# Rails Environment
RAILS_ENV=staging
RAILS_MAX_THREADS=5

# Database Configuration
DATABASE_HOST=your_actual_db_host          # e.g., 192.168.1.100 or db.example.com
DATABASE_PORT=3306
DATABASE_USERNAME=your_db_username
DATABASE_PASSWORD=your_db_password
DATABASE_NAME=rais_payment_gateway_staging

# Razorpay Credentials
RAZORPAY_KEY_ID=rzp_test_SCNon27YdwiJYi
RAZORPAY_KEY_SECRET=ZaMak8CTRaXDqXBpAU0eR6hT
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret

# Application URLs
APP_HOST=https://staging.yourdomain.com
FRONTEND_URL=https://staging-frontend.yourdomain.com

# Security
SECRET_KEY_BASE=$(rails secret)
```

### Step 3: Generate Secret Key Base

```bash
rails secret
```

Copy the output and paste it as `SECRET_KEY_BASE` in your `.env.staging` file.

---

## 🚀 Running in Staging Mode

### Option 1: Using .env.staging file

```bash
# Load staging environment variables
export $(cat .env.staging | xargs)

# Create database
RAILS_ENV=staging rails db:create

# Run migrations
RAILS_ENV=staging rails db:migrate

# Start server
RAILS_ENV=staging rails server -p 3000
```

### Option 2: Using dotenv-rails (Recommended)

Update your application to load the correct env file:

```bash
# In your deployment script or server startup
RAILS_ENV=staging rails server
```

---

## 🔍 Troubleshooting Common Issues

### Issue 1: "Can't connect to MySQL server on 'localhost' (10061)"

**Solution**: Check if MySQL is running and accessible:

```bash
# Test MySQL connection
mysql -h your_db_host -u your_username -p

# If using localhost, ensure MySQL is running
sudo systemctl status mysql  # Linux
brew services list           # macOS
```

### Issue 2: "Access denied for user"

**Solution**: Verify database credentials:

```bash
# Test connection with credentials
mysql -h DATABASE_HOST -u DATABASE_USERNAME -p DATABASE_NAME
```

### Issue 3: "Unknown database"

**Solution**: Create the database first:

```bash
RAILS_ENV=staging rails db:create
```

### Issue 4: "Can't connect through socket '/tmp/mysql.sock'"

**Solution**: The new configuration fixes this by using TCP/IP for staging. Ensure:

1. `DATABASE_HOST` is set (not using socket)
2. `DATABASE_PORT` is set to 3306
3. Remove any `DATABASE_SOCKET` environment variable

---

## 🔐 Database Connection Methods

### Method 1: TCP/IP (Recommended for Staging/Production)

```yaml
host: localhost  # or IP address
port: 3306
# No socket specified
```

**Pros:**
- Works across networks
- More reliable for remote connections
- Better for containerized environments

### Method 2: Unix Socket (Local Development Only)

```yaml
socket: /tmp/mysql.sock
host: ~  # Disable host when using socket
```

**Pros:**
- Faster for local connections
- Lower overhead

---

## 📊 Verify Configuration

### Check Database Connection

```bash
RAILS_ENV=staging rails dbconsole
```

If successful, you'll see the MySQL prompt:

```
mysql>
```

### Check Environment Variables

```bash
RAILS_ENV=staging rails runner 'puts ActiveRecord::Base.connection_db_config.configuration_hash'
```

This will show your active database configuration.

---

## 🌐 Production Deployment Checklist

- [ ] Set `RAILS_ENV=production`
- [ ] Update `DATABASE_HOST` to production database server
- [ ] Update `DATABASE_USERNAME` and `DATABASE_PASSWORD`
- [ ] Generate new `SECRET_KEY_BASE` for production
- [ ] Use live Razorpay credentials (`rzp_live_...`)
- [ ] Configure webhook URL to production domain
- [ ] Set up SSL/TLS for database connection (if required)
- [ ] Enable database connection pooling
- [ ] Set up database backups

---

## 📝 Environment Variables Reference

| Variable | Development | Staging | Production | Required |
|----------|-------------|---------|------------|----------|
| `RAILS_ENV` | development | staging | production | Yes |
| `DATABASE_HOST` | localhost | staging-db | prod-db | Yes |
| `DATABASE_PORT` | 3306 | 3306 | 3306 | Yes |
| `DATABASE_USERNAME` | root | app_user | app_user | Yes |
| `DATABASE_PASSWORD` | (empty) | password | password | Yes |
| `DATABASE_NAME` | dev_db | staging_db | prod_db | Yes |
| `RAZORPAY_KEY_ID` | test_key | test_key | live_key | Yes |
| `RAZORPAY_KEY_SECRET` | test_secret | test_secret | live_secret | Yes |
| `SECRET_KEY_BASE` | generated | generated | generated | Yes |

---

## 🔄 Migration Guide

If you're migrating from the old configuration:

1. **Backup your current `.env` file**
   ```bash
   cp .env .env.backup
   ```

2. **Update environment variables** in your `.env` file to match the new format

3. **Test the connection**
   ```bash
   rails db:migrate:status
   ```

4. **If successful**, you're good to go!

---

## 💡 Tips

1. **Never commit** `.env.staging` or `.env.production` to version control
2. **Use different databases** for each environment
3. **Test database connection** before deploying
4. **Monitor connection pool** usage in production
5. **Set up read replicas** for high-traffic production environments

---

## 📚 Additional Resources

- [Rails Database Configuration Guide](https://guides.rubyonrails.org/configuring.html#configuring-a-database)
- [MySQL Connection Options](https://dev.mysql.com/doc/refman/8.0/en/connecting.html)
- [Razorpay API Documentation](https://razorpay.com/docs/api/)

---

**Need Help?**

If you encounter any issues, check the Rails logs:

```bash
tail -f log/staging.log
```
