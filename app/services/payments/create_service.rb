# frozen_string_literal: true

# Service to create a new payment
# This service handles idempotency and creates the payment record
#
# Usage:
#   result = Payments::CreateService.new(amount: 499.00, idempotency_key: 'uuid', metadata: {}).call
#   if result[:success]
#     payment = result[:payment]
#   else
#     errors = result[:errors]
#   end

module Payments
  class CreateService
    attr_reader :amount, :idempotency_key, :currency, :user_id, :metadata
    
    def initialize(amount:, idempotency_key:, currency: 'INR', user_id: nil, metadata: {})
      @amount = amount
      @idempotency_key = idempotency_key
      @currency = currency
      @user_id = user_id
      @metadata = metadata
    end
    
    def call
      # Check if payment already exists with this idempotency key
      existing_payment = Payment.find_by(idempotency_key: idempotency_key)
      
      if existing_payment
        Rails.logger.info "Payment already exists with idempotency_key: #{idempotency_key}"
        return success_response(existing_payment)
      end
      
      # Create new payment
      payment = Payment.new(
        amount: amount,
        idempotency_key: idempotency_key,
        currency: currency,
        user_id: user_id,
        metadata: metadata,
        status: 'created'
      )
      
      if payment.save
        Rails.logger.info "Payment created: #{payment.public_reference}"
        success_response(payment)
      else
        Rails.logger.error "Failed to create payment: #{payment.errors.full_messages.join(', ')}"
        error_response(payment.errors.full_messages)
      end
    rescue StandardError => e
      Rails.logger.error "Error creating payment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_response([e.message])
    end
    
    private
    
    def success_response(payment)
      {
        success: true,
        payment: payment,
        public_reference: payment.public_reference
      }
    end
    
    def error_response(errors)
      {
        success: false,
        errors: errors
      }
    end
  end
end
