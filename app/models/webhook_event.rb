# frozen_string_literal: true

# == Schema Information
#
# Table name: webhook_events
#
#  id                   :bigint           not null, primary key
#  event_id             :string(255)      not null
#  event_type           :string(100)      not null
#  razorpay_payment_id  :string(255)
#  razorpay_order_id    :string(255)
#  payload              :json             not null
#  signature            :string(255)      not null
#  processed            :boolean          not null, default(false)
#  processed_at         :datetime
#  processing_error     :text
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_webhook_events_on_event_id                (event_id) UNIQUE
#  index_webhook_events_on_event_type              (event_type)
#  index_webhook_events_on_razorpay_payment_id     (razorpay_payment_id)
#  index_webhook_events_on_razorpay_order_id       (razorpay_order_id)
#  index_webhook_events_on_processed               (processed)
#  index_webhook_events_on_processed_and_created_at (processed, created_at)
#  index_webhook_events_on_created_at              (created_at)
#

class WebhookEvent < ApplicationRecord
  # Validations
  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :payload, presence: true
  validates :signature, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :unprocessed, -> { where(processed: false) }
  scope :processed, -> { where(processed: true) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :payment_captured, -> { where(event_type: 'payment.captured') }
  scope :payment_failed, -> { where(event_type: 'payment.failed') }
  
  # Instance Methods
  
  # Mark webhook as processed
  def mark_as_processed!
    update!(processed: true, processed_at: Time.current, processing_error: nil)
  end
  
  # Mark webhook as failed with error
  def mark_as_failed!(error_message)
    update!(processed: false, processing_error: error_message)
  end
  
  # Get payment entity from payload
  def payment_entity
    payload.dig('payload', 'payment', 'entity')
  end
  
  # Get order entity from payload
  def order_entity
    payload.dig('payload', 'order', 'entity')
  end
  
  # Extract payment ID from payload
  def extract_payment_id
    payment_entity&.dig('id') || razorpay_payment_id
  end
  
  # Extract order ID from payload
  def extract_order_id
    payment_entity&.dig('order_id') || razorpay_order_id
  end
  
  # Check if this is a payment event
  def payment_event?
    event_type.start_with?('payment.')
  end
  
  # Check if this is a successful payment event
  def payment_captured_event?
    event_type == 'payment.captured'
  end
  
  # Check if this is a failed payment event
  def payment_failed_event?
    event_type == 'payment.failed'
  end
end
