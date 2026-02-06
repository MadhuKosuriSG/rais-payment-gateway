# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment, type: :model do
  describe 'associations' do
    it { should have_many(:payment_attempts).dependent(:restrict_with_error) }
    it { should have_many(:gateway_transactions).through(:payment_attempts) }
  end

  describe 'validations' do
    subject { build(:payment) }

    it { should validate_presence_of(:public_reference) }
    it { should validate_uniqueness_of(:public_reference) }
    it { should validate_presence_of(:idempotency_key) }
    it { should validate_uniqueness_of(:idempotency_key) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:currency) }
    it { should validate_inclusion_of(:currency).in_array(%w[INR USD EUR]) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[created initiated pending captured failed cancelled]) }
  end

  describe 'callbacks' do
    describe '#generate_public_reference' do
      it 'generates a unique public reference on create' do
        payment = build(:payment, public_reference: nil)
        payment.save
        
        expect(payment.public_reference).to be_present
        expect(payment.public_reference).to start_with('PAY_')
        expect(payment.public_reference.length).to eq(16) # PAY_ + 12 chars
      end

      it 'does not override existing public reference' do
        payment = build(:payment, public_reference: 'PAY_CUSTOM123')
        payment.save
        
        expect(payment.public_reference).to eq('PAY_CUSTOM123')
      end

      it 'ensures uniqueness' do
        payment1 = create(:payment)
        payment2 = create(:payment)
        
        expect(payment1.public_reference).not_to eq(payment2.public_reference)
      end
    end

    describe '#set_default_currency' do
      it 'sets currency to INR by default' do
        payment = create(:payment, currency: nil)
        expect(payment.currency).to eq('INR')
      end

      it 'does not override provided currency' do
        payment = create(:payment, currency: 'USD')
        expect(payment.currency).to eq('USD')
      end
    end
  end

  describe 'scopes' do
    let!(:old_payment) { create(:payment, created_at: 2.days.ago) }
    let!(:new_payment) { create(:payment, created_at: 1.day.ago) }
    let!(:captured_payment) { create(:payment, :captured) }
    let!(:failed_payment) { create(:payment, :failed) }
    let!(:pending_payment) { create(:payment, :pending) }

    describe '.recent' do
      it 'returns payments in reverse chronological order' do
        expect(Payment.recent.first).to eq(new_payment)
        expect(Payment.recent.last).to eq(old_payment)
      end
    end

    describe '.successful' do
      it 'returns only captured payments' do
        expect(Payment.successful).to contain_exactly(captured_payment)
      end
    end

    describe '.failed' do
      it 'returns only failed payments' do
        expect(Payment.failed).to contain_exactly(failed_payment)
      end
    end

    describe '.pending_payments' do
      it 'returns payments in created, initiated, or pending status' do
        created_payment = create(:payment, status: 'created')
        initiated_payment = create(:payment, status: 'initiated')
        
        expect(Payment.pending_payments).to contain_exactly(
          created_payment, initiated_payment, pending_payment, old_payment, new_payment
        )
      end
    end
  end

  describe 'instance methods' do
    describe '#latest_attempt' do
      let(:payment) { create(:payment) }
      let!(:first_attempt) { create(:payment_attempt, payment: payment, attempt_number: 1) }
      let!(:second_attempt) { create(:payment_attempt, payment: payment, attempt_number: 2) }

      it 'returns the most recent attempt' do
        expect(payment.latest_attempt).to eq(second_attempt)
      end
    end

    describe '#latest_transaction' do
      let(:payment) { create(:payment) }
      let(:attempt) { create(:payment_attempt, payment: payment) }
      let!(:old_transaction) { create(:gateway_transaction, payment_attempt: attempt, created_at: 2.hours.ago) }
      let!(:new_transaction) { create(:gateway_transaction, payment_attempt: attempt, created_at: 1.hour.ago) }

      it 'returns the most recent transaction' do
        expect(payment.latest_transaction).to eq(new_transaction)
      end
    end

    describe '#retryable?' do
      it 'returns true for created status' do
        payment = build(:payment, status: 'created')
        expect(payment.retryable?).to be true
      end

      it 'returns true for failed status' do
        payment = build(:payment, status: 'failed')
        expect(payment.retryable?).to be true
      end

      it 'returns false for captured status' do
        payment = build(:payment, status: 'captured')
        expect(payment.retryable?).to be false
      end

      it 'returns false for pending status' do
        payment = build(:payment, status: 'pending')
        expect(payment.retryable?).to be false
      end
    end

    describe 'status update methods' do
      let(:payment) { create(:payment, status: 'created') }

      describe '#mark_as_captured!' do
        it 'updates status to captured' do
          payment.mark_as_captured!
          expect(payment.reload.status).to eq('captured')
        end
      end

      describe '#mark_as_failed!' do
        it 'updates status to failed' do
          payment.mark_as_failed!
          expect(payment.reload.status).to eq('failed')
        end
      end

      describe '#mark_as_pending!' do
        it 'updates status to pending' do
          payment.mark_as_pending!
          expect(payment.reload.status).to eq('pending')
        end
      end

      describe '#mark_as_initiated!' do
        it 'updates status to initiated' do
          payment.mark_as_initiated!
          expect(payment.reload.status).to eq('initiated')
        end
      end
    end

    describe '#amount_in_rupees' do
      it 'returns formatted amount with rupee symbol' do
        payment = build(:payment, amount: 499.00)
        expect(payment.amount_in_rupees).to eq('₹499.0')
      end
    end

    describe '#as_json' do
      let(:payment) { create(:payment, :with_attempts) }

      it 'includes expected attributes' do
        json = payment.as_json
        
        expect(json).to include('id', 'public_reference', 'amount', 'currency', 'status', 'created_at', 'updated_at')
        expect(json).to include('amount_in_rupees')
        expect(json).to include('payment_attempts')
      end

      it 'excludes sensitive attributes' do
        json = payment.as_json
        
        expect(json).not_to include('idempotency_key')
      end
    end
  end

  describe 'idempotency' do
    it 'prevents duplicate payments with same idempotency_key' do
      payment1 = create(:payment, idempotency_key: 'unique-key-123')
      payment2 = build(:payment, idempotency_key: 'unique-key-123')
      
      expect(payment2).not_to be_valid
      expect(payment2.errors[:idempotency_key]).to include('has already been taken')
    end
  end
end
