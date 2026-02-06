# frozen_string_literal: true

# Service to create a Razorpay order for a payment
# This service creates a Razorpay order and stores the attempt
#
# Usage:
#   result = Payments::CreateOrderService.new(payment: payment).call
#   if result[:success]
#     order_id = result[:razorpay_order_id]
#     key_id = result[:key_id]
#   else
#     errors = result[:errors]
#   end

module Payments
  class CreateOrderService
    attr_reader :payment
    
    def initialize(payment:)
      @payment = payment
    end
    
    def call
      # Validate payment can create order
      unless payment.retryable? || payment.status_initiated?
        return error_response(['Payment is not in a valid state to create order'])
      end
      
      # Create Razorpay order
      razorpay_order = create_razorpay_order
      
      unless razorpay_order
        return error_response(['Failed to create Razorpay order'])
      end
      
      # Create payment attempt record
      payment_attempt = create_payment_attempt(razorpay_order)
      
      unless payment_attempt.persisted?
        return error_response(payment_attempt.errors.full_messages)
      end
      
      # Update payment status to initiated
      payment.mark_as_initiated!
      
      Rails.logger.info "Razorpay order created: #{razorpay_order.id} for payment: #{payment.public_reference}"
      
      success_response(razorpay_order, payment_attempt)
    rescue StandardError => e
      Rails.logger.error "Error creating Razorpay order: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_response([e.message])
    end
    
    private
    
    def create_razorpay_order
      # Convert amount to paise (Razorpay expects smallest currency unit)
      amount_in_paise = (payment.amount * 100).to_i
      
      # Create order via Razorpay API
      Razorpay::Order.create(
        amount: amount_in_paise,
        currency: payment.currency,
        receipt: payment.public_reference,
        notes: {
          payment_id: payment.id,
          public_reference: payment.public_reference
        }
      )
    rescue Razorpay::Error => e
      Rails.logger.error "Razorpay API Error: #{e.message}"
      nil
    end
    
    def create_payment_attempt(razorpay_order)
      PaymentAttempt.create(
        payment: payment,
        razorpay_order_id: razorpay_order.id,
        amount: payment.amount,
        currency: payment.currency,
        status: 'created',
        razorpay_order_status: razorpay_order.status
      )
    end
    
    def success_response(razorpay_order, payment_attempt)
      {
        success: true,
        razorpay_order_id: razorpay_order.id,
        key_id: ENV['RAZORPAY_KEY_ID'],
        amount: payment.amount,
        currency: payment.currency,
        payment_attempt: payment_attempt,
        order_details: {
          id: razorpay_order.id,
          amount: razorpay_order.amount,
          currency: razorpay_order.currency,
          receipt: razorpay_order.receipt
        }
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
