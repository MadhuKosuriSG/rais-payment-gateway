# frozen_string_literal: true

# Migration to create webhook_events table
# Stores ALL incoming webhooks for audit, replay, and idempotency
# CRITICAL: event_id must be unique to prevent duplicate processing
class CreateWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_events do |t|
      # Razorpay's event ID (unique identifier for the webhook event)
      # This is CRITICAL for idempotency
      t.string :event_id, null: false, limit: 255, index: { unique: true }
      
      # Event type (payment.captured, payment.failed, etc.)
      t.string :event_type, null: false, limit: 100, index: true
      
      # Payment and order IDs from webhook payload
      t.string :razorpay_payment_id, limit: 255, index: true
      t.string :razorpay_order_id, limit: 255, index: true
      
      # Full webhook payload (for audit/replay)
      t.json :payload, null: false
      
      # Razorpay signature (for verification)
      t.string :signature, null: false, limit: 255
      
      # Processing status
      t.boolean :processed, null: false, default: false, index: true
      t.datetime :processed_at
      t.text :processing_error
      
      # Timestamp (when webhook was received)
      t.timestamps
    end
    
    # Composite index for finding unprocessed events
    add_index :webhook_events, [:processed, :created_at]
    
    # Index for cleanup jobs
    add_index :webhook_events, :created_at
  end
end
