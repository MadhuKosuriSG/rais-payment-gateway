# frozen_string_literal: true

# Migration to create gateway_transactions table
# Maps Razorpay payment_id to our system
# Stores actual payment details from Razorpay
class CreateGatewayTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :gateway_transactions do |t|
      # Foreign key to payment_attempts table
      t.references :payment_attempt, null: false, foreign_key: true, index: true
      
      # Razorpay payment ID (unique identifier for the actual payment)
      t.string :razorpay_payment_id, null: false, limit: 255, index: { unique: true }
      
      # Razorpay order ID (for cross-reference)
      t.string :razorpay_order_id, null: false, limit: 255, index: true
      
      # Actual amount processed by Razorpay
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: 'INR', limit: 3
      
      # Razorpay payment status (captured, failed, authorized, etc.)
      t.string :status, null: false, limit: 50, index: true
      
      # Payment method details (for analytics and support)
      t.string :method, limit: 50  # card, netbanking, upi, wallet
      t.string :card_last4, limit: 4  # Last 4 digits of card
      t.string :card_network, limit: 20  # Visa, Mastercard, etc.
      t.string :bank, limit: 100  # Bank name (if netbanking/UPI)
      
      # Customer details from Razorpay
      t.string :email, limit: 255
      t.string :contact, limit: 15
      
      # Razorpay fees (for reconciliation)
      t.decimal :fee, precision: 10, scale: 2
      t.decimal :tax, precision: 10, scale: 2
      
      # Error details (if payment failed)
      t.string :error_code, limit: 100
      t.text :error_description
      
      # Capture timestamp
      t.datetime :captured_at
      
      # Timestamps
      t.timestamps
    end
    
    # Index for reporting and analytics
    add_index :gateway_transactions, :created_at
  end
end
