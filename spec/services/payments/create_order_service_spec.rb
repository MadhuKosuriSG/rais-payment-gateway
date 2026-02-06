# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::CreateOrderService, type: :service do
  let(:payment) { create(:payment, status: 'created', amount: 499.00) }
  let(:razorpay_order_double) { double('RazorpayOrder', id: 'order_test123', amount: 49900, currency: 'INR', status: 'created', receipt: payment.public_reference) }

  subject(:service) { described_class.new(payment: payment) }

  describe '#call' do
    before do
      allow(Razorpay::Order).to receive(:create).and_return(razorpay_order_double)
    end

    context 'when payment is in valid state' do
      it 'creates a Razorpay order' do
        expect(Razorpay::Order).to receive(:create).with(
          amount: 49900, # 499.00 * 100
          currency: 'INR',
          receipt: payment.public_reference,
          notes: {
            payment_id: payment.id,
            public_reference: payment.public_reference
          }
        )
        
        service.call
      end

      it 'creates a payment attempt' do
        expect { service.call }.to change(PaymentAttempt, :count).by(1)
      end

      it 'sets correct payment attempt attributes' do
        result = service.call
        attempt = PaymentAttempt.last
        
        expect(attempt.payment).to eq(payment)
        expect(attempt.razorpay_order_id).to eq('order_test123')
        expect(attempt.amount).to eq(499.00)
        expect(attempt.currency).to eq('INR')
        expect(attempt.status).to eq('created')
        expect(attempt.attempt_number).to eq(1)
      end

      it 'updates payment status to initiated' do
        service.call
        expect(payment.reload.status).to eq('initiated')
      end

      it 'returns success response' do
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:razorpay_order_id]).to eq('order_test123')
        expect(result[:key_id]).to eq(ENV['RAZORPAY_KEY_ID'])
        expect(result[:amount]).to eq(499.00)
        expect(result[:currency]).to eq('INR')
      end

      it 'includes order details in response' do
        result = service.call
        
        expect(result[:order_details]).to include(
          id: 'order_test123',
          amount: 49900,
          currency: 'INR',
          receipt: payment.public_reference
        )
      end
    end

    context 'when payment is already initiated' do
      before { payment.update(status: 'initiated') }

      it 'allows creating a new order' do
        result = service.call
        expect(result[:success]).to be true
      end
    end

    context 'when payment is captured' do
      before { payment.update(status: 'captured') }

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/not in a valid state/)
      end

      it 'does not create payment attempt' do
        expect { service.call }.not_to change(PaymentAttempt, :count)
      end
    end

    context 'when payment is pending' do
      before { payment.update(status: 'pending') }

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/not in a valid state/)
      end
    end

    context 'when Razorpay API fails' do
      before do
        allow(Razorpay::Order).to receive(:create).and_raise(Razorpay::Error, 'API Error')
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Failed to create Razorpay order')
      end

      it 'does not create payment attempt' do
        expect { service.call }.not_to change(PaymentAttempt, :count)
      end

      it 'does not update payment status' do
        service.call
        expect(payment.reload.status).to eq('created')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Razorpay API Error/)
        service.call
      end
    end

    context 'when payment attempt creation fails' do
      before do
        allow_any_instance_of(PaymentAttempt).to receive(:persisted?).and_return(false)
        allow_any_instance_of(PaymentAttempt).to receive(:errors).and_return(
          double(full_messages: ['Validation error'])
        )
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Validation error')
      end
    end

    context 'with retry scenario' do
      let!(:first_attempt) { create(:payment_attempt, payment: payment, attempt_number: 1, status: 'failed') }

      it 'creates second attempt with incremented number' do
        result = service.call
        second_attempt = PaymentAttempt.last
        
        expect(second_attempt.attempt_number).to eq(2)
      end
    end

    context 'amount conversion' do
      it 'converts amount to paise correctly' do
        payment.update(amount: 1234.56)
        
        expect(Razorpay::Order).to receive(:create).with(
          hash_including(amount: 123456)
        )
        
        service.call
      end

      it 'handles whole numbers' do
        payment.update(amount: 500.00)
        
        expect(Razorpay::Order).to receive(:create).with(
          hash_including(amount: 50000)
        )
        
        service.call
      end
    end

    context 'when exception occurs' do
      before do
        allow(Razorpay::Order).to receive(:create).and_raise(StandardError, 'Unexpected error')
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Unexpected error')
      end

      it 'logs the error with backtrace' do
        expect(Rails.logger).to receive(:error).with(/Error creating Razorpay order/)
        expect(Rails.logger).to receive(:error).with(anything)
        service.call
      end
    end
  end
end
