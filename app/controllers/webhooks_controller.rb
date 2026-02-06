# frozen_string_literal: true

# Webhooks Controller
# Handles incoming webhooks from Razorpay
# THIS IS THE SOURCE OF TRUTH FOR PAYMENT STATUS
#
# Endpoint:
# - POST /webhooks/razorpay - Receive Razorpay webhooks

class WebhooksController < ApplicationController
  # Skip CSRF verification for webhooks
  skip_before_action :verify_authenticity_token, if: :json_request?
  
  # POST /webhooks/razorpay
  # Receive and process Razorpay webhooks
  #
  # Razorpay sends webhooks with the following structure:
  # {
  #   "event": "payment.captured",
  #   "payload": {
  #     "payment": {
  #       "entity": {
  #         "id": "pay_xyz123",
  #         "order_id": "order_abc456",
  #         "amount": 49900,
  #         "currency": "INR",
  #         "status": "captured",
  #         ...
  #       }
  #     }
  #   }
  # }
  #
  # Headers:
  # - X-Razorpay-Event-Id: Unique event ID
  # - X-Razorpay-Signature: HMAC signature for verification
  def razorpay
    # Extract webhook data
    event_id = request.headers['X-Razorpay-Event-Id']
    signature = request.headers['X-Razorpay-Signature']
    event_type = params[:event]
    payload = request.request_parameters
    
    # Validate required headers
    unless event_id.present? && signature.present?
      Rails.logger.error 'Webhook missing required headers'
      return render json: {
        success: false,
        error: 'Missing required headers'
      }, status: :bad_request
    end
    
    # Log webhook receipt
    Rails.logger.info "Received webhook: #{event_type} (#{event_id})"
    
    # Process webhook using service
    result = Webhooks::ProcessService.new(
      event_id: event_id,
      event_type: event_type,
      payload: payload.to_unsafe_h,
      signature: signature
    ).call
    
    if result[:success]
      if result[:already_processed]
        Rails.logger.info "Webhook already processed: #{event_id}"
        render json: { success: true, message: 'Already processed' }, status: :ok
      else
        Rails.logger.info "Webhook processed successfully: #{event_id}"
        render json: { success: true }, status: :ok
      end
    else
      Rails.logger.error "Webhook processing failed: #{event_id} - #{result[:errors]}"
      render json: {
        success: false,
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    render json: {
      success: false,
      error: 'Internal server error'
    }, status: :internal_server_error
  end
  
  private
  
  def json_request?
    request.format.json?
  end
end
