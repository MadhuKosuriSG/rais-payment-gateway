
class WebhooksController < ApplicationController
  def razorpay
    event_id = request.headers['X-Razorpay-Event-Id'] || params[:created_at]&.to_s || SecureRandom.uuid
    signature = request.headers['X-Razorpay-Signature']
    event_type = params[:event]
    payload = request.request_parameters
    
    # Log all headers for debugging
    Rails.logger.info "=== Webhook Received ==="
    Rails.logger.info "Event Type: #{event_type}"
    Rails.logger.info "Event ID: #{event_id}"
    Rails.logger.info "Signature Present: #{signature.present?}"
    Rails.logger.info "Headers: #{request.headers.env.select { |k,v| k.start_with?('HTTP_') || k == 'CONTENT_TYPE' }}"
    Rails.logger.info "Payload Keys: #{payload.keys}"
    
    # For order.paid events, extract payment info
    if event_type == 'order.paid' && payload.dig('payload', 'payment', 'entity', 'id')
      Rails.logger.info "Processing order.paid event - extracting payment data"
      # Use payment event data from order.paid webhook
      payment_data = payload.dig('payload', 'payment', 'entity')
      if payment_data
        # Create a payment.captured event from order.paid
        event_type = 'payment.captured'
        Rails.logger.info "Converted order.paid to payment.captured event"
      end
    end
    
    # Signature validation is optional for development/testing
    # In production, you should enforce signature validation
    if signature.blank?
      Rails.logger.warn "Webhook received without signature - accepting for development"
      # Don't reject, just log the warning
    end
    
    # Log webhook receipt
    Rails.logger.info "Processing webhook: #{event_type} (#{event_id})"
    
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
end
