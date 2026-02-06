# frozen_string_literal: true

# Payments Controller
# Handles payment creation, order creation, and status retrieval
#
# Endpoints:
# - POST /payments - Create a new payment
# - POST /payments/:id/create_order - Create Razorpay order
# - GET /payments/:id - Get payment status

class PaymentsController < ApplicationController
  before_action :set_payment, only: [:show, :create_order]
  
  # POST /payments
  # Create a new payment
  #
  # Request Body:
  # {
  #   "amount": 499.00,
  #   "idempotency_key": "uuid-here",
  #   "currency": "INR",
  #   "metadata": {
  #     "product_id": 123,
  #     "user_email": "user@example.com"
  #   }
  # }
  #
  # Response:
  # {
  #   "success": true,
  #   "payment": {...},
  #   "public_reference": "PAY_ABC123"
  # }
  def create
    # Validate required parameters
    unless params[:amount].present? && params[:idempotency_key].present?
      return render json: {
        success: false,
        errors: ['Amount and idempotency_key are required']
      }, status: :unprocessable_entity
    end
    
    # Create payment using service
    result = Payments::CreateService.new(
      amount: params[:amount].to_f,
      idempotency_key: params[:idempotency_key],
      currency: params[:currency] || 'INR',
      user_id: params[:user_id],
      metadata: params[:metadata] || {}
    ).call
    
    if result[:success]
      render json: {
        success: true,
        payment: result[:payment].as_json,
        public_reference: result[:public_reference]
      }, status: :created
    else
      render json: {
        success: false,
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /payments/:id/create_order
  # Create Razorpay order for a payment
  #
  # Response:
  # {
  #   "success": true,
  #   "razorpay_order_id": "order_xyz123",
  #   "key_id": "rzp_test_...",
  #   "amount": 499.00,
  #   "currency": "INR"
  # }
  def create_order
    result = Payments::CreateOrderService.new(payment: @payment).call
    
    if result[:success]
      render json: {
        success: true,
        razorpay_order_id: result[:razorpay_order_id],
        key_id: result[:key_id],
        amount: result[:amount],
        currency: result[:currency],
        payment_reference: @payment.public_reference
      }, status: :ok
    else
      render json: {
        success: false,
        errors: result[:errors]
      }, status: :unprocessable_entity
    end
  end
  
  # GET /payments/:id
  # Get payment status (used by frontend for polling)
  #
  # Response:
  # {
  #   "success": true,
  #   "payment": {
  #     "id": 1,
  #     "public_reference": "PAY_ABC123",
  #     "amount": 499.00,
  #     "currency": "INR",
  #     "status": "captured",
  #     "created_at": "2024-01-01T00:00:00Z",
  #     "updated_at": "2024-01-01T00:05:00Z"
  #   }
  # }
  def show
    render json: {
      success: true,
      payment: @payment.as_json(
        include: {
          payment_attempts: {
            only: [:id, :razorpay_order_id, :status, :attempt_number, :created_at],
            include: {
              gateway_transactions: {
                only: [:id, :razorpay_payment_id, :status, :method, :captured_at]
              }
            }
          }
        }
      )
    }, status: :ok
  end
  
  private
  
  def set_payment
    @payment = Payment.find_by(id: params[:id]) || Payment.find_by(public_reference: params[:id])
    
    unless @payment
      render json: {
        success: false,
        errors: ['Payment not found']
      }, status: :not_found
    end
  end
end
