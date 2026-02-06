# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks API', type: :request do
  let(:payment) { create(:payment, :initiated) }
  let(:payment_attempt) { create(:payment_attempt, payment: payment, razorpay_order_id: 'order_test123') }
  let(:event_id) { "event_#{SecureRandom.hex(10)}" }
  
  let(:webhook_payload) do
    {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_test456',
            order_id: payment_attempt.razorpay_order_id,
            amount: 49900,
            currency: 'INR',
            status: 'captured',
            method: 'card',
            card: {
              last4: '1111',
              network: 'Visa'
            },
            email: 'customer@example.com',
            contact: '+919876543210',
            fee: 990,
            tax: 180,
            created_at: Time.current.to_i
          }
        }
      }
    }
  end

  let(:headers) do
    {
      'X-Razorpay-Event-Id' => event_id,
      'X-Razorpay-Signature' => 'valid_signature',
      'Content-Type' => 'application/json'
    }
  end

  before do
    # Mock signature verification
    allow_any_instance_of(Webhooks::ProcessService).to receive(:verify_signature?).and_return(true)
  end

  describe 'POST /webhooks/razorpay' do
    context 'with valid webhook' do
      it 'processes webhook successfully' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:ok)
      end

      it 'returns success response' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
      end

      it 'stores webhook event' do
        expect {
          post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        }.to change(WebhookEvent, :count).by(1)
      end

      it 'creates gateway transaction' do
        expect {
          post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        }.to change(GatewayTransaction, :count).by(1)
      end

      it 'updates payment status' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        expect(payment.reload.status).to eq('captured')
      end

      it 'logs webhook receipt' do
        expect(Rails.logger).to receive(:info).with(/Received webhook: payment.captured/)
        expect(Rails.logger).to receive(:info).with(/Webhook processed successfully/)
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
      end
    end

    context 'with duplicate webhook (idempotency)' do
      before do
        # Process webhook once
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
      end

      it 'does not create duplicate webhook event' do
        expect {
          post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        }.not_to change(WebhookEvent, :count)
      end

      it 'does not create duplicate transaction' do
        expect {
          post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        }.not_to change(GatewayTransaction, :count)
      end

      it 'returns success with already processed message' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['message']).to eq('Already processed')
      end

      it 'logs duplicate webhook' do
        expect(Rails.logger).to receive(:info).with(/Webhook already processed/)
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
      end
    end

    context 'with missing headers' do
      it 'returns bad request when event_id is missing' do
        headers.delete('X-Razorpay-Event-Id')
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Missing required headers')
      end

      it 'returns bad request when signature is missing' do
        headers.delete('X-Razorpay-Signature')
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with invalid signature' do
      before do
        allow_any_instance_of(Webhooks::ProcessService).to receive(:verify_signature?).and_return(false)
      end

      it 'returns unprocessable entity' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json['success']).to be false
        expect(json['errors']).to include('Invalid webhook signature')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Webhook processing failed/)
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
      end
    end

    context 'with payment.failed event' do
      let(:failed_payload) do
        webhook_payload.deep_merge(
          event: 'payment.failed',
          payload: {
            payment: {
              entity: {
                status: 'failed',
                error_code: 'BAD_REQUEST_ERROR',
                error_description: 'Payment failed'
              }
            }
          }
        )
      end

      it 'processes failed payment' do
        post '/webhooks/razorpay', params: failed_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(payment.reload.status).to eq('failed')
      end

      it 'stores error details' do
        post '/webhooks/razorpay', params: failed_payload.to_json, headers: headers
        transaction = GatewayTransaction.last
        
        expect(transaction.error_code).to eq('BAD_REQUEST_ERROR')
        expect(transaction.error_description).to eq('Payment failed')
      end
    end

    context 'when payment attempt not found' do
      let(:webhook_payload) do
        {
          event: 'payment.captured',
          payload: {
            payment: {
              entity: {
                id: 'pay_test456',
                order_id: 'order_nonexistent',
                amount: 49900,
                currency: 'INR',
                status: 'captured'
              }
            }
          }
        }
      end

      it 'returns unprocessable entity' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'stores webhook but marks as failed' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        webhook = WebhookEvent.last
        
        expect(webhook.processed).to be false
        expect(webhook.processing_error).to be_present
      end
    end

    context 'when exception occurs' do
      before do
        allow(Webhooks::ProcessService).to receive(:new).and_raise(StandardError, 'Unexpected error')
      end

      it 'returns internal server error' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns error message' do
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json['success']).to be false
        expect(json['error']).to eq('Internal server error')
      end

      it 'logs the error with backtrace' do
        expect(Rails.logger).to receive(:error).with(/Webhook error/)
        expect(Rails.logger).to receive(:error).with(anything)
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
      end
    end

    context 'with different payment methods' do
      it 'handles UPI payment' do
        webhook_payload[:payload][:payment][:entity][:method] = 'upi'
        webhook_payload[:payload][:payment][:entity].delete(:card)
        
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        transaction = GatewayTransaction.last
        
        expect(transaction.method).to eq('upi')
      end

      it 'handles netbanking payment' do
        webhook_payload[:payload][:payment][:entity][:method] = 'netbanking'
        webhook_payload[:payload][:payment][:entity][:bank] = 'HDFC'
        webhook_payload[:payload][:payment][:entity].delete(:card)
        
        post '/webhooks/razorpay', params: webhook_payload.to_json, headers: headers
        transaction = GatewayTransaction.last
        
        expect(transaction.method).to eq('netbanking')
        expect(transaction.bank).to eq('HDFC')
      end
    end
  end
end
