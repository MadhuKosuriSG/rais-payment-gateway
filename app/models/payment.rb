# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id                :bigint           not null, primary key
#  public_reference  :string(64)       not null
#  idempotency_key   :string(255)      not null
#  amount            :decimal(10, 2)   not null
#  currency          :string(3)        not null, default("INR")
#  status            :string(20)       not null, default("created")
#  user_id           :bigint
#  metadata          :json
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_payments_on_public_reference         (public_reference) UNIQUE
#  index_payments_on_idempotency_key          (idempotency_key) UNIQUE
#  index_payments_on_status                   (status)
#  index_payments_on_status_and_created_at    (status, created_at)
#  index_payments_on_user_id                  (user_id)
#

class Payment < ApplicationRecord
  # Associations
  has_many :payment_attempts, dependent: :restrict_with_error
  has_many :gateway_transactions, through: :payment_attempts
  
  # Validations
  validates :public_reference, presence: true, uniqueness: true
  validates :idempotency_key, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: %w[INR USD EUR] }
  validates :status, presence: true, inclusion: { in: %w[created initiated pending captured failed cancelled] }
  
  # Enums (using string values for better debugging)
  enum status: {
    created: 'created',       # Payment record created, no Razorpay order yet
    initiated: 'initiated',   # Razorpay order created, waiting for user action
    pending: 'pending',       # Payment in progress (user opened checkout)
    captured: 'captured',     # Payment successful (money received)
    failed: 'failed',         # Payment failed
    cancelled: 'cancelled'    # Payment cancelled by user or system
  }, _prefix: true
  
  # Callbacks
  before_validation :generate_public_reference, on: :create
  before_validation :set_default_currency, on: :create
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'captured') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending_payments, -> { where(status: %w[created initiated pending]) }
  
  # Instance Methods
  
  # Get the latest payment attempt
  def latest_attempt
    payment_attempts.order(attempt_number: :desc).first
  end
  
  # Get the latest gateway transaction
  def latest_transaction
    gateway_transactions.order(created_at: :desc).first
  end
  
  # Check if payment can be retried
  def retryable?
    status_created? || status_failed?
  end
  
  # Mark payment as captured
  def mark_as_captured!
    update!(status: 'captured')
  end
  
  # Mark payment as failed
  def mark_as_failed!
    update!(status: 'failed')
  end
  
  # Mark payment as pending
  def mark_as_pending!
    update!(status: 'pending')
  end
  
  # Mark payment as initiated
  def mark_as_initiated!
    update!(status: 'initiated')
  end
  
  # Human-readable amount
  def amount_in_rupees
    "₹#{amount}"
  end
  
  # Convert to JSON for API responses
  def as_json(options = {})
    super(options.merge(
      only: [:id, :public_reference, :amount, :currency, :status, :created_at, :updated_at],
      methods: [:amount_in_rupees],
      include: {
        payment_attempts: {
          only: [:id, :razorpay_order_id, :status, :attempt_number, :created_at]
        }
      }
    ))
  end
  
  private
  
  # Generate a unique public reference (e.g., PAY_abc123xyz)
  def generate_public_reference
    return if public_reference.present?
    
    loop do
      self.public_reference = "PAY_#{SecureRandom.alphanumeric(12).upcase}"
      break unless Payment.exists?(public_reference: public_reference)
    end
  end
  
  # Set default currency to INR
  def set_default_currency
    self.currency ||= 'INR'
  end
end
