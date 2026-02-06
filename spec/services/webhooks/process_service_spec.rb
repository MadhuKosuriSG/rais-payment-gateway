# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::ProcessService, type: :service do
  let(:payment) { create(:payment, :initiated) }
  let(:payment_attempt) { create(:payment_attempt, payment: payment, razorpay_order_id: 'order_test123') }
  let(:event_id) { 'event_test123' }
  let(:razorpay_payment_id) { 'pay_test456' }
  
  let(:payload) do
    {
      'event' => 'payment.captured',
      'payload' => {
        'payment' => {
          'entity' => {
            'id' => razorpay_payment_id,
            'order_id' => payment_attempt.razorpay_order_id,
            'amount' => 49900,
            'currency' => 'INR',
            'status' => 'captured',
            'method' => 'card',
            'card' => {
              'last4' => '1111',
              'network' => 'Visa'
            },
            'email' => 'customer@example.com',
            'contact' => '+919876543210',
            'fee' => 990,
            'tax' => 180,
            'created_at' => Time.current.to_i
          }
        }
      }
    }
  end
  
  let(:signature) { 'valid_signature' }
  
  subject(:service) do
    described_class.new(
      event_id: event_id,
      event_type: 'payment.captured',
      payload: payload,
      signature: signature
    )
  end

  before do
    # Mock signature verification
    allow_any_instance_of(described_class).to receive(:verify_signature?).and_return(true)
  end

  describe '#call' do
    context 'when webhook is valid and new' do
      it 'stores webhook event' do
        expect { service.call }.to change(WebhookEvent, :count).by(1)
      end

      it 'creates gateway transaction' do
        expect { service.call }.to change(GatewayTransaction, :count).by(1)
      end

      it 'updates payment attempt status' do
        service.call
        expect(payment_attempt.reload.status).to eq('captured')
      end

      it 'updates payment status' do
        service.call
        expect(payment.reload.status).to eq('captured')
      end

      it 'marks webhook as processed' do
        service.call
        webhook = WebhookEvent.last
        
        expect(webhook.processed).to be true
        expect(webhook.processed_at).to be_present
      end

      it 'returns success response' do
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:webhook_event]).to be_a(WebhookEvent)
      end

      it 'stores correct gateway transaction details' do
        service.call
        transaction = GatewayTransaction.last
        
        expect(transaction.razorpay_payment_id).to eq(razorpay_payment_id)
        expect(transaction.razorpay_order_id).to eq(payment_attempt.razorpay_order_id)
        expect(transaction.amount).to eq(499.00) # Converted from paise
        expect(transaction.currency).to eq('INR')
        expect(transaction.status).to eq('captured')
        expect(transaction.method).to eq('card')
        expect(transaction.card_last4).to eq('1111')
        expect(transaction.card_network).to eq('Visa')
        expect(transaction.email).to eq('customer@example.com')
        expect(transaction.contact).to eq('+919876543210')
        expect(transaction.fee).to eq(9.90)
        expect(transaction.tax).to eq(1.80)
      end
    end

    context 'when signature verification fails' do
      before do
        allow_any_instance_of(described_class).to receive(:verify_signature?).and_return(false)
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Invalid webhook signature')
      end

      it 'does not store webhook event' do
        expect { service.call }.not_to change(WebhookEvent, :count)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Webhook signature verification failed/)
        service.call
      end
    end

    context 'when webhook is duplicate (idempotency)' do
      let!(:existing_webhook) do
        create(:webhook_event, :processed, event_id: event_id)
      end

      it 'does not create new webhook event' do
        expect { service.call }.not_to change(WebhookEvent, :count)
      end

      it 'returns success with already_processed flag' do
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:already_processed]).to be true
      end

      it 'does not create duplicate transaction' do
        expect { service.call }.not_to change(GatewayTransaction, :count)
      end

      it 'logs the duplicate' do
        expect(Rails.logger).to receive(:info).with(/Webhook already processed/)
        service.call
      end
    end

    context 'when payment.failed event' do
      let(:failed_payload) do
        {
          'event' => 'payment.failed',
          'payload' => {
            'payment' => {
              'entity' => {
                'id' => razorpay_payment_id,
                'order_id' => payment_attempt.razorpay_order_id,
                'amount' => 49900,
                'currency' => 'INR',
                'status' => 'failed',
                'method' => 'card',
                'email' => 'customer@example.com',
                'contact' => '+919876543210',
                'error_code' => 'BAD_REQUEST_ERROR',
                'error_description' => 'Payment failed due to insufficient funds',
                'created_at' => Time.current.to_i
              }
            }
          }
        }
      end

      subject(:service) do
        described_class.new(
          event_id: event_id,
          event_type: 'payment.failed',
          payload: failed_payload,
          signature: signature
        )
      end

      it 'creates gateway transaction with error details' do
        service.call
        transaction = GatewayTransaction.last
        
        expect(transaction.status).to eq('failed')
        expect(transaction.error_code).to eq('BAD_REQUEST_ERROR')
        expect(transaction.error_description).to eq('Payment failed due to insufficient funds')
      end

      it 'updates payment attempt to failed' do
        service.call
        expect(payment_attempt.reload.status).to eq('failed')
      end

      it 'updates payment to failed' do
        service.call
        expect(payment.reload.status).to eq('failed')
      end
    end

    context 'when payment.authorized event' do
      let(:authorized_payload) do
        {
          'event' => 'payment.authorized',
          'payload' => {
            'payment' => {
              'entity' => {
                'id' => razorpay_payment_id,
                'order_id' => payment_attempt.razorpay_order_id,
                'amount' => 49900,
                'currency' => 'INR',
                'status' => 'authorized',
                'method' => 'card',
                'created_at' => Time.current.to_i
              }
            }
          }
        }
      end

      subject(:service) do
        described_class.new(
          event_id: event_id,
          event_type: 'payment.authorized',
          payload: authorized_payload,
          signature: signature
        )
      end

      it 'updates payment attempt to authorized' do
        service.call
        expect(payment_attempt.reload.status).to eq('authorized')
      end
    end

    context 'when payment attempt not found' do
      let(:payload) do
        {
          'event' => 'payment.captured',
          'payload' => {
            'payment' => {
              'entity' => {
                'id' => razorpay_payment_id,
                'order_id' => 'order_nonexistent',
                'amount' => 49900,
                'currency' => 'INR',
                'status' => 'captured'
              }
            }
          }
        }
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
      end

      it 'marks webhook as failed' do
        service.call
        webhook = WebhookEvent.last
        
        expect(webhook.processed).to be false
        expect(webhook.processing_error).to include('Payment attempt not found')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Webhook processing failed/)
        service.call
      end
    end

    context 'when unknown event type' do
      subject(:service) do
        described_class.new(
          event_id: event_id,
          event_type: 'order.paid',
          payload: payload,
          signature: signature
        )
      end

      it 'stores webhook but does not process' do
        result = service.call
        
        expect(result[:success]).to be true
      end

      it 'logs the unknown event' do
        expect(Rails.logger).to receive(:info).with(/Unhandled webhook event type/)
        service.call
      end
    end

    context 'when exception occurs during processing' do
      before do
        allow(PaymentAttempt).to receive(:find_by).and_raise(StandardError, 'Database error')
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Database error')
      end

      it 'logs the error with backtrace' do
        expect(Rails.logger).to receive(:error).with(/Error processing webhook/)
        expect(Rails.logger).to receive(:error).with(anything)
        service.call
      end
    end

    context 'race condition handling' do
      it 'handles concurrent webhook storage gracefully' do
        # Simulate race condition
        allow(WebhookEvent).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordNotUnique)
        allow(WebhookEvent).to receive(:find_by).and_return(create(:webhook_event, event_id: event_id))
        
        result = service.call
        expect(result[:success]).to be true
      end
    end

    context 'with different payment methods' do
      it 'handles UPI payments' do
        payload['payload']['payment']['entity']['method'] = 'upi'
        payload['payload']['payment']['entity'].delete('card')
        
        service.call
        transaction = GatewayTransaction.last
        
        expect(transaction.method).to eq('upi')
        expect(transaction.card_last4).to be_nil
      end

      it 'handles netbanking payments' do
        payload['payload']['payment']['entity']['method'] = 'netbanking'
        payload['payload']['payment']['entity']['bank'] = 'HDFC'
        payload['payload']['payment']['entity'].delete('card')
        
        service.call
        transaction = GatewayTransaction.last
        
        expect(transaction.method).to eq('netbanking')
        expect(transaction.bank).to eq('HDFC')
      end
    end
  end
end
