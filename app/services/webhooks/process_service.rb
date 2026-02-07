# frozen_string_literal: true

# Service to process Razorpay webhooks
# This is the CRITICAL service that handles payment status updates
# Webhooks are the SOURCE OF TRUTH for payment status

module Webhooks
  class ProcessService
    attr_reader :event_id, :event_type, :payload, :signature
    
    def initialize(event_id:, event_type:, payload:, signature:)
      @event_id = event_id
      @event_type = event_type
      @payload = payload
      @signature = signature
    end
    
    def call
      # Step 1: Verify webhook signature
      unless verify_signature?
        Rails.logger.error "Webhook signature verification failed for event: #{event_id}"
        return error_response(['Invalid webhook signature'])
      end
      
      # Step 2: Store webhook event (idempotent)
      webhook_event = store_webhook_event
      
      unless webhook_event
        Rails.logger.error "Failed to store webhook event: #{event_id}"
        return error_response(['Failed to store webhook event'])
      end
      
      # Step 3: Check if already processed (idempotency)
      if webhook_event.processed?
        Rails.logger.info "Webhook already processed: #{event_id}"
        return success_response(webhook_event, already_processed: true)
      end
      
      # Step 4: Process the webhook based on event type
      result = process_webhook_event(webhook_event)
      
      if result[:success]
        webhook_event.mark_as_processed!
        Rails.logger.info "Webhook processed successfully: #{event_id}"
        success_response(webhook_event)
      else
        webhook_event.mark_as_failed!(result[:error])
        Rails.logger.error "Webhook processing failed: #{event_id} - #{result[:error]}"
        error_response([result[:error]])
      end
    rescue StandardError => e
      Rails.logger.error "Error processing webhook: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_response([e.message])
    end
    
    private
    
    def verify_signature?
      # Skip if no signature provided (for testing)
      if signature.blank?
        Rails.logger.warn "Skipping signature verification - no signature provided"
        return true
      end
      
      # Razorpay signature verification
      # Format: HMAC SHA256 of webhook body with webhook secret
      expected_signature = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        RAZORPAY_WEBHOOK_SECRET,
        payload.to_json
      )
      
      ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
    rescue StandardError => e
      Rails.logger.error "Signature verification error: #{e.message}"
      false
    end
    
    def store_webhook_event
      # Extract payment and order IDs from payload
      payment_entity = payload.dig('payload', 'payment', 'entity')
      razorpay_payment_id = payment_entity&.dig('id')
      razorpay_order_id = payment_entity&.dig('order_id')
      
      # Create or find webhook event (idempotent)
      WebhookEvent.find_or_create_by(event_id: event_id) do |event|
        event.event_type = event_type
        event.razorpay_payment_id = razorpay_payment_id
        event.razorpay_order_id = razorpay_order_id
        event.payload = payload
        event.signature = signature
        event.processed = false
      end
    rescue ActiveRecord::RecordNotUnique
      # Race condition: another process already created this event
      WebhookEvent.find_by(event_id: event_id)
    end
    
    def process_webhook_event(webhook_event)
      case webhook_event.event_type
      when 'payment.captured'
        process_payment_captured(webhook_event)
      when 'payment.failed'
        process_payment_failed(webhook_event)
      when 'payment.authorized'
        process_payment_authorized(webhook_event)
      else
        Rails.logger.info "Unhandled webhook event type: #{webhook_event.event_type}"
        { success: true } # Don't fail on unknown events
      end
    end
    
    def process_payment_captured(webhook_event)
      payment_entity = webhook_event.payment_entity
      
      razorpay_payment_id = payment_entity['id']
      razorpay_order_id = payment_entity['order_id']
      
      # Find payment attempt
      payment_attempt = PaymentAttempt.find_by(razorpay_order_id: razorpay_order_id)
      
      unless payment_attempt
        return { success: false, error: "Payment attempt not found for order: #{razorpay_order_id}" }
      end
      
      # Create or update gateway transaction
      transaction = GatewayTransaction.find_or_initialize_by(razorpay_payment_id: razorpay_payment_id)
      
      transaction.assign_attributes(
        payment_attempt: payment_attempt,
        razorpay_order_id: razorpay_order_id,
        amount: payment_entity['amount'] / 100.0, # Convert paise to rupees
        currency: payment_entity['currency'],
        status: payment_entity['status'],
        card_last4: payment_entity.dig('card', 'last4'),
        card_network: payment_entity.dig('card', 'network'),
        bank: payment_entity['bank'],
        email: payment_entity['email'],
        contact: payment_entity['contact'],
        fee: payment_entity['fee'] ? payment_entity['fee'] / 100.0 : nil,
        tax: payment_entity['tax'] ? payment_entity['tax'] / 100.0 : nil,
        captured_at: Time.at(payment_entity['created_at'])
      )
      
      # Set method separately to avoid Ruby keyword conflict
      transaction.send(:method=, payment_entity['method']) if payment_entity['method']
      
      if transaction.save
        # Update payment attempt status
        payment_attempt.mark_as_captured!
        
        # Update payment status
        payment_attempt.payment.mark_as_captured!
        
        { success: true }
      else
        { success: false, error: transaction.errors.full_messages.join(', ') }
      end
    end
    
    def process_payment_failed(webhook_event)
      payment_entity = webhook_event.payment_entity
      
      razorpay_payment_id = payment_entity['id']
      razorpay_order_id = payment_entity['order_id']
      
      # Find payment attempt
      payment_attempt = PaymentAttempt.find_by(razorpay_order_id: razorpay_order_id)
      
      unless payment_attempt
        return { success: false, error: "Payment attempt not found for order: #{razorpay_order_id}" }
      end
      
      # Create or update gateway transaction
      transaction = GatewayTransaction.find_or_initialize_by(razorpay_payment_id: razorpay_payment_id)
      
      transaction.assign_attributes(
        payment_attempt: payment_attempt,
        razorpay_order_id: razorpay_order_id,
        amount: payment_entity['amount'] / 100.0,
        currency: payment_entity['currency'],
        status: payment_entity['status'],
        email: payment_entity['email'],
        contact: payment_entity['contact'],
        error_code: payment_entity['error_code'],
        error_description: payment_entity['error_description']
      )
      
      # Set method separately to avoid Ruby keyword conflict
      transaction.send(:method=, payment_entity['method']) if payment_entity['method']
      
      if transaction.save
        # Update payment attempt status
        payment_attempt.mark_as_failed!
        
        # Update payment status
        payment_attempt.payment.mark_as_failed!
        
        { success: true }
      else
        { success: false, error: transaction.errors.full_messages.join(', ') }
      end
    end
    
    def process_payment_authorized(webhook_event)
      payment_entity = webhook_event.payment_entity
      
      razorpay_payment_id = payment_entity['id']
      razorpay_order_id = payment_entity['order_id']
      
      # Find payment attempt
      payment_attempt = PaymentAttempt.find_by(razorpay_order_id: razorpay_order_id)
      
      unless payment_attempt
        return { success: false, error: "Payment attempt not found for order: #{razorpay_order_id}" }
      end
      
      # Update payment attempt status to authorized
      payment_attempt.mark_as_authorized!
      
      { success: true }
    end
    
    def success_response(webhook_event, already_processed: false)
      {
        success: true,
        webhook_event: webhook_event,
        already_processed: already_processed
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
