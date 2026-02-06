# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::CreateService, type: :service do
  describe '#call' do
    let(:amount) { 499.00 }
    let(:idempotency_key) { SecureRandom.uuid }
    let(:currency) { 'INR' }
    let(:metadata) { { product_id: 1, user_email: 'test@example.com' } }

    subject(:service) do
      described_class.new(
        amount: amount,
        idempotency_key: idempotency_key,
        currency: currency,
        metadata: metadata
      )
    end

    context 'when creating a new payment' do
      it 'creates a payment successfully' do
        expect { service.call }.to change(Payment, :count).by(1)
      end

      it 'returns success response' do
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:payment]).to be_a(Payment)
        expect(result[:public_reference]).to be_present
      end

      it 'sets correct attributes' do
        result = service.call
        payment = result[:payment]
        
        expect(payment.amount).to eq(amount)
        expect(payment.idempotency_key).to eq(idempotency_key)
        expect(payment.currency).to eq(currency)
        expect(payment.metadata).to eq(metadata.stringify_keys)
        expect(payment.status).to eq('created')
      end

      it 'generates public_reference' do
        result = service.call
        payment = result[:payment]
        
        expect(payment.public_reference).to be_present
        expect(payment.public_reference).to start_with('PAY_')
      end
    end

    context 'when payment with same idempotency_key exists' do
      let!(:existing_payment) do
        create(:payment, idempotency_key: idempotency_key, amount: 999.00)
      end

      it 'does not create a new payment' do
        expect { service.call }.not_to change(Payment, :count)
      end

      it 'returns existing payment' do
        result = service.call
        
        expect(result[:success]).to be true
        expect(result[:payment]).to eq(existing_payment)
        expect(result[:payment].amount).to eq(999.00) # Original amount
      end

      it 'logs the duplicate attempt' do
        expect(Rails.logger).to receive(:info).with(/Payment already exists/)
        service.call
      end
    end

    context 'when validation fails' do
      let(:amount) { -100 } # Invalid amount

      it 'does not create a payment' do
        expect { service.call }.not_to change(Payment, :count)
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'includes validation errors' do
        result = service.call
        
        expect(result[:errors]).to include(/amount/)
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Payment).to receive(:new).and_raise(StandardError, 'Database error')
      end

      it 'returns error response' do
        result = service.call
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('Database error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error creating payment/)
        expect(Rails.logger).to receive(:error).with(anything)
        service.call
      end
    end

    context 'with optional parameters' do
      it 'accepts user_id' do
        service = described_class.new(
          amount: amount,
          idempotency_key: idempotency_key,
          user_id: 123
        )
        
        result = service.call
        expect(result[:payment].user_id).to eq(123)
      end

      it 'defaults to INR currency' do
        service = described_class.new(
          amount: amount,
          idempotency_key: idempotency_key
        )
        
        result = service.call
        expect(result[:payment].currency).to eq('INR')
      end
    end
  end
end
