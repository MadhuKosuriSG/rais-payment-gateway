# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payments API', type: :request do
  describe 'POST /payments' do
    let(:valid_params) do
      {
        amount: 499.00,
        idempotency_key: SecureRandom.uuid,
        currency: 'INR',
        metadata: {
          product_id: 1,
          user_email: 'test@example.com'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new payment' do
        expect {
          post '/payments', params: valid_params, as: :json
        }.to change(Payment, :count).by(1)
      end

      it 'returns created status' do
        post '/payments', params: valid_params, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'returns payment details' do
        post '/payments', params: valid_params, as: :json
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['payment']).to be_present
        expect(json['payment']['amount']).to eq(499.0)
        expect(json['payment']['currency']).to eq('INR')
        expect(json['payment']['status']).to eq('created')
        expect(json['public_reference']).to be_present
      end
    end

    context 'with duplicate idempotency_key' do
      let!(:existing_payment) do
        create(:payment, idempotency_key: valid_params[:idempotency_key])
      end

      it 'does not create a new payment' do
        expect {
          post '/payments', params: valid_params, as: :json
        }.not_to change(Payment, :count)
      end

      it 'returns existing payment' do
        post '/payments', params: valid_params, as: :json
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['payment']['id']).to eq(existing_payment.id)
      end
    end

    context 'with missing parameters' do
      it 'returns error when amount is missing' do
        post '/payments', params: { idempotency_key: SecureRandom.uuid }, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['errors']).to include('Amount and idempotency_key are required')
      end

      it 'returns error when idempotency_key is missing' do
        post '/payments', params: { amount: 499.00 }, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end

    context 'with invalid amount' do
      it 'returns error for negative amount' do
        post '/payments', params: valid_params.merge(amount: -100), as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['errors']).to be_present
      end

      it 'returns error for zero amount' do
        post '/payments', params: valid_params.merge(amount: 0), as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /payments/:id/create_order' do
    let(:payment) { create(:payment, status: 'created') }
    let(:razorpay_order_double) do
      double('RazorpayOrder',
        id: 'order_test123',
        amount: 49900,
        currency: 'INR',
        status: 'created',
        receipt: payment.public_reference
      )
    end

    before do
      allow(Razorpay::Order).to receive(:create).and_return(razorpay_order_double)
    end

    context 'with valid payment ID' do
      it 'creates a Razorpay order' do
        post "/payments/#{payment.id}/create_order", as: :json
        
        expect(response).to have_http_status(:ok)
      end

      it 'returns order details' do
        post "/payments/#{payment.id}/create_order", as: :json
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['razorpay_order_id']).to eq('order_test123')
        expect(json['key_id']).to eq(ENV['RAZORPAY_KEY_ID'])
        expect(json['amount']).to eq(499.0)
        expect(json['currency']).to eq('INR')
      end

      it 'creates payment attempt' do
        expect {
          post "/payments/#{payment.id}/create_order", as: :json
        }.to change(PaymentAttempt, :count).by(1)
      end

      it 'updates payment status' do
        post "/payments/#{payment.id}/create_order", as: :json
        expect(payment.reload.status).to eq('initiated')
      end
    end

    context 'with public_reference instead of ID' do
      it 'works with public_reference' do
        post "/payments/#{payment.public_reference}/create_order", as: :json
        
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid payment ID' do
      it 'returns not found error' do
        post '/payments/99999/create_order', as: :json
        
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['errors']).to include('Payment not found')
      end
    end

    context 'when payment is already captured' do
      let(:payment) { create(:payment, status: 'captured') }

      it 'returns error' do
        post "/payments/#{payment.id}/create_order", as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end

    context 'when Razorpay API fails' do
      before do
        allow(Razorpay::Order).to receive(:create).and_raise(Razorpay::Error, 'API Error')
      end

      it 'returns error response' do
        post "/payments/#{payment.id}/create_order", as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end

  describe 'GET /payments/:id' do
    let(:payment) { create(:payment, :with_successful_transaction) }

    context 'with valid payment ID' do
      it 'returns payment details' do
        get "/payments/#{payment.id}", as: :json
        
        expect(response).to have_http_status(:ok)
      end

      it 'includes payment attributes' do
        get "/payments/#{payment.id}", as: :json
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['payment']['id']).to eq(payment.id)
        expect(json['payment']['public_reference']).to eq(payment.public_reference)
        expect(json['payment']['amount']).to eq(payment.amount)
        expect(json['payment']['status']).to eq(payment.status)
      end

      it 'includes payment attempts' do
        get "/payments/#{payment.id}", as: :json
        json = JSON.parse(response.body)
        
        expect(json['payment']['payment_attempts']).to be_present
        expect(json['payment']['payment_attempts'].first).to include('razorpay_order_id', 'status')
      end

      it 'includes gateway transactions' do
        get "/payments/#{payment.id}", as: :json
        json = JSON.parse(response.body)
        
        attempt = json['payment']['payment_attempts'].first
        expect(attempt['gateway_transactions']).to be_present
      end
    end

    context 'with public_reference' do
      it 'returns payment details' do
        get "/payments/#{payment.public_reference}", as: :json
        
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['payment']['id']).to eq(payment.id)
      end
    end

    context 'with invalid payment ID' do
      it 'returns not found error' do
        get '/payments/99999', as: :json
        
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['errors']).to include('Payment not found')
      end
    end
  end
end
