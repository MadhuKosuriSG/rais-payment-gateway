# frozen_string_literal: true

# Razorpay Configuration
# This initializer sets up the Razorpay client with credentials from environment variables
#
# Required Environment Variables:
# - RAZORPAY_KEY_ID: Your Razorpay Key ID (from dashboard)
# - RAZORPAY_KEY_SECRET: Your Razorpay Key Secret (from dashboard)
# - RAZORPAY_WEBHOOK_SECRET: Webhook secret for signature verification
#
# Get your credentials from: https://dashboard.razorpay.com/app/keys

require 'razorpay'

# Initialize Razorpay client
Razorpay.setup(
  ENV.fetch('RAZORPAY_KEY_ID', nil),
  ENV.fetch('RAZORPAY_KEY_SECRET', nil)
)

# Store webhook secret in a constant for easy access
RAZORPAY_WEBHOOK_SECRET = ENV.fetch('RAZORPAY_WEBHOOK_SECRET', nil)

# Validate that credentials are present
if Rails.env.production?
  raise 'RAZORPAY_KEY_ID is not set' if ENV['RAZORPAY_KEY_ID'].blank?
  raise 'RAZORPAY_KEY_SECRET is not set' if ENV['RAZORPAY_KEY_SECRET'].blank?
  raise 'RAZORPAY_WEBHOOK_SECRET is not set' if ENV['RAZORPAY_WEBHOOK_SECRET'].blank?
elsif Rails.env.development?
  if ENV['RAZORPAY_KEY_ID'].blank?
    Rails.logger.warn '⚠️  RAZORPAY_KEY_ID is not set. Please set it in .env file'
  end
  
  if ENV['RAZORPAY_KEY_SECRET'].blank?
    Rails.logger.warn '⚠️  RAZORPAY_KEY_SECRET is not set. Please set it in .env file'
  end
  
  if ENV['RAZORPAY_WEBHOOK_SECRET'].blank?
    Rails.logger.warn '⚠️  RAZORPAY_WEBHOOK_SECRET is not set. Please set it in .env file'
  end
end

# Log Razorpay initialization (without exposing secrets)
Rails.logger.info '✅ Razorpay initialized successfully' if ENV['RAZORPAY_KEY_ID'].present?
