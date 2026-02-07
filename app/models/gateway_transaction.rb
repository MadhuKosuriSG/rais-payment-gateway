# frozen_string_literal: true

# == Schema Information
#
# Table name: gateway_transactions
#
#  id                  :bigint           not null, primary key
#  payment_attempt_id  :bigint           not null
#  razorpay_payment_id :string(255)      not null
#  razorpay_order_id   :string(255)      not null
#  amount              :decimal(10, 2)   not null
#  currency            :string(3)        not null, default("INR")
#  status              :string(50)       not null
#  method              :string(50)
#  card_last4          :string(4)
#  card_network        :string(20)
#  bank                :string(100)
#  email               :string(255)
#  contact             :string(15)
#  fee                 :decimal(10, 2)
#  tax                 :decimal(10, 2)
#  error_code          :string(100)
#  error_description   :text
#  captured_at         :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_gateway_transactions_on_payment_attempt_id   (payment_attempt_id)
#  index_gateway_transactions_on_razorpay_payment_id  (razorpay_payment_id) UNIQUE
#  index_gateway_transactions_on_razorpay_order_id    (razorpay_order_id)
#  index_gateway_transactions_on_status               (status)
#  index_gateway_transactions_on_created_at           (created_at)
#
# Foreign Keys
#
#  fk_rails_...  (payment_attempt_id => payment_attempts.id)
#

class GatewayTransaction < ApplicationRecord
  # Associations
  belongs_to :payment_attempt
  has_one :payment, through: :payment_attempt
  
  # Validations
  validates :razorpay_payment_id, presence: true, uniqueness: true
  validates :razorpay_order_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'captured') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_method, ->(method) { where(method: method) }
  
  # Instance Methods
  
  # Check if transaction is successful
  def successful?
    status == 'captured'
  end
  
  # Check if transaction failed
  def failed?
    status == 'failed'
  end
  
  # Get payment method display name
  def method_display_name
    case method
    when 'card' then "Card (#{card_network} #{card_last4})"
    when 'netbanking' then "Net Banking (#{bank})"
    when 'upi' then 'UPI'
    when 'wallet' then 'Wallet'
    else method&.titleize
    end
  end
  
  # Calculate net amount (amount - fee - tax)
  def net_amount  
    amount - (fee || 0) - (tax || 0)
  end
  
  # Human-readable error message
  def error_message
    return nil unless error_description.present?
    
    "#{error_code}: #{error_description}"
  end
  
  # Convert to JSON for API responses
  def as_json(options = {})
    super(options.merge(
      only: [:id, :razorpay_payment_id, :amount, :currency, :status, :method, :captured_at, :created_at],
      methods: [:method_display_name, :net_amount]
    ))
  end
end
