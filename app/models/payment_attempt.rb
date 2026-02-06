# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_attempts
#
#  id                     :bigint           not null, primary key
#  payment_id             :bigint           not null
#  razorpay_order_id      :string(255)      not null
#  amount                 :decimal(10, 2)   not null
#  currency               :string(3)        not null, default("INR")
#  status                 :string(20)       not null, default("created")
#  razorpay_order_status  :string(50)
#  attempt_number         :integer          not null, default(1)
#  expires_at             :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_payment_attempts_on_payment_id                    (payment_id)
#  index_payment_attempts_on_razorpay_order_id             (razorpay_order_id) UNIQUE
#  index_payment_attempts_on_status                        (status)
#  index_payment_attempts_on_payment_id_and_attempt_number (payment_id, attempt_number)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id)
#

class PaymentAttempt < ApplicationRecord
  # Associations
  belongs_to :payment
  has_many :gateway_transactions, dependent: :restrict_with_error
  
  # Validations
  validates :razorpay_order_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: %w[created pending authorized captured failed expired] }
  validates :attempt_number, presence: true, numericality: { greater_than: 0 }
  
  # Enums
  enum status: {
    created: 'created',       # Razorpay order created
    pending: 'pending',       # User opened checkout, payment in progress
    authorized: 'authorized', # Payment authorized (for manual capture)
    captured: 'captured',     # Payment captured successfully
    failed: 'failed',         # Payment failed
    expired: 'expired'        # Razorpay order expired (~15 mins)
  }, _prefix: true
  
  # Callbacks
  before_validation :set_attempt_number, on: :create
  before_validation :set_amount_from_payment, on: :create
  before_validation :set_expiry_time, on: :create
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_payment, ->(payment_id) { where(payment_id: payment_id) }
  scope :active, -> { where(status: %w[created pending]) }
  
  # Instance Methods
  
  # Get the latest gateway transaction for this attempt
  def latest_transaction
    gateway_transactions.order(created_at: :desc).first
  end
  
  # Check if attempt is expired
  def expired?
    expires_at.present? && expires_at < Time.current
  end
  
  # Mark as captured
  def mark_as_captured!
    update!(status: 'captured')
  end
  
  # Mark as failed
  def mark_as_failed!
    update!(status: 'failed')
  end
  
  # Mark as pending
  def mark_as_pending!
    update!(status: 'pending')
  end
  
  # Mark as authorized
  def mark_as_authorized!
    update!(status: 'authorized')
  end
  
  private
  
  # Set attempt number based on existing attempts for this payment
  def set_attempt_number
    return if attempt_number.present?
    
    last_attempt = payment.payment_attempts.maximum(:attempt_number) || 0
    self.attempt_number = last_attempt + 1
  end
  
  # Set amount from parent payment
  def set_amount_from_payment
    self.amount ||= payment.amount
    self.currency ||= payment.currency
  end
  
  # Razorpay orders expire after 15 minutes
  def set_expiry_time
    self.expires_at ||= Time.current + 15.minutes
  end
end
