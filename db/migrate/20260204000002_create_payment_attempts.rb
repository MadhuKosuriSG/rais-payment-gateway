# frozen_string_literal: true

# Migration to create payment_attempts table
# Each Razorpay order creation is an attempt
# A payment may have multiple attempts if user retries
class CreatePaymentAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_attempts do |t|
      # Foreign key to payments table
      t.references :payment, null: false, foreign_key: true, index: true
      
      # Razorpay order ID (unique identifier from Razorpay)
      t.string :razorpay_order_id, null: false, limit: 255, index: { unique: true }
      
      # Amount and currency for this attempt
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: 'INR', limit: 3
      
      # Attempt status (created, pending, authorized, captured, failed, expired)
      t.string :status, null: false, default: 'created', limit: 20, index: true
      
      # Raw status from Razorpay API
      t.string :razorpay_order_status, limit: 50
      
      # Retry counter (1, 2, 3...)
      t.integer :attempt_number, null: false, default: 1
      
      # Razorpay orders expire after ~15 minutes
      t.datetime :expires_at
      
      # Timestamps
      t.timestamps
    end
    
    # Composite index for fetching latest attempt
    add_index :payment_attempts, [:payment_id, :attempt_number]
  end
end
