# frozen_string_literal: true

# Migration to create payments table
# This table stores the logical payment intent
class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      # User-visible payment reference (e.g., PAY_abc123xyz)
      t.string :public_reference, null: false, limit: 64, index: { unique: true }
      
      # Frontend-generated UUID for idempotency (prevents double-click payments)
      t.string :idempotency_key, null: false, index: { unique: true }
      
      # Payment amount and currency
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: 'INR', limit: 3
      
      # Payment status (created, initiated, pending, captured, failed, cancelled)
      t.string :status, null: false, default: 'created', limit: 20, index: true
      
      # Optional: Link to users table (if authentication exists)
      t.bigint :user_id, index: true
      
      # Additional metadata (product_id, user_email, description, etc.)
      t.json :metadata
      
      # Timestamps
      t.timestamps
    end
    
    # Composite index for filtering and reporting
    add_index :payments, [:status, :created_at]
  end
end
