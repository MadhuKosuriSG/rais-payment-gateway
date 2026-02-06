# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentAttempt, type: :model do
  describe 'associations' do
    it { should belong_to(:payment) }
    it { should have_many(:gateway_transactions).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { build(:payment_attempt) }

    it { should validate_presence_of(:razorpay_order_id) }
    it { should validate_uniqueness_of(:razorpay_order_id) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:currency) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[created pending authorized captured failed expired]) }
    it { should validate_presence_of(:attempt_number) }
    it { should validate_numericality_of(:attempt_number).is_greater_than(0) }
  end

  describe 'callbacks' do
    describe '#set_attempt_number' do
      let(:payment) { create(:payment) }

      it 'sets attempt_number to 1 for first attempt' do
        attempt = create(:payment_attempt, payment: payment, attempt_number: nil)
        expect(attempt.attempt_number).to eq(1)
      end

      it 'increments attempt_number for subsequent attempts' do
        create(:payment_attempt, payment: payment, attempt_number: 1)
        second_attempt = create(:payment_attempt, payment: payment, attempt_number: nil)
        
        expect(second_attempt.attempt_number).to eq(2)
      end

      it 'does not override provided attempt_number' do
        attempt = create(:payment_attempt, payment: payment, attempt_number: 5)
        expect(attempt.attempt_number).to eq(5)
      end
    end

    describe '#set_amount_from_payment' do
      let(:payment) { create(:payment, amount: 999.00, currency: 'USD') }

      it 'sets amount from payment if not provided' do
        attempt = create(:payment_attempt, payment: payment, amount: nil)
        expect(attempt.amount).to eq(999.00)
      end

      it 'sets currency from payment if not provided' do
        attempt = create(:payment_attempt, payment: payment, currency: nil)
        expect(attempt.currency).to eq('USD')
      end

      it 'does not override provided amount' do
        attempt = create(:payment_attempt, payment: payment, amount: 500.00)
        expect(attempt.amount).to eq(500.00)
      end
    end

    describe '#set_expiry_time' do
      it 'sets expires_at to 15 minutes from now' do
        Timecop.freeze(Time.current) do
          attempt = create(:payment_attempt, expires_at: nil)
          expect(attempt.expires_at).to be_within(1.second).of(15.minutes.from_now)
        end
      end

      it 'does not override provided expires_at' do
        custom_time = 1.hour.from_now
        attempt = create(:payment_attempt, expires_at: custom_time)
        expect(attempt.expires_at).to be_within(1.second).of(custom_time)
      end
    end
  end

  describe 'scopes' do
    let!(:old_attempt) { create(:payment_attempt, created_at: 2.days.ago) }
    let!(:new_attempt) { create(:payment_attempt, created_at: 1.day.ago) }
    let(:payment) { create(:payment) }
    let!(:payment_attempt1) { create(:payment_attempt, payment: payment) }
    let!(:payment_attempt2) { create(:payment_attempt, payment: payment) }
    let!(:created_attempt) { create(:payment_attempt, status: 'created') }
    let!(:pending_attempt) { create(:payment_attempt, status: 'pending') }
    let!(:captured_attempt) { create(:payment_attempt, status: 'captured') }

    describe '.recent' do
      it 'returns attempts in reverse chronological order' do
        expect(PaymentAttempt.recent.first).to eq(captured_attempt)
      end
    end

    describe '.for_payment' do
      it 'returns attempts for specific payment' do
        expect(PaymentAttempt.for_payment(payment.id)).to contain_exactly(payment_attempt1, payment_attempt2)
      end
    end

    describe '.active' do
      it 'returns only created and pending attempts' do
        expect(PaymentAttempt.active).to contain_exactly(created_attempt, pending_attempt, old_attempt, new_attempt, payment_attempt1, payment_attempt2)
      end
    end
  end

  describe 'instance methods' do
    describe '#latest_transaction' do
      let(:attempt) { create(:payment_attempt) }
      let!(:old_transaction) { create(:gateway_transaction, payment_attempt: attempt, created_at: 2.hours.ago) }
      let!(:new_transaction) { create(:gateway_transaction, payment_attempt: attempt, created_at: 1.hour.ago) }

      it 'returns the most recent transaction' do
        expect(attempt.latest_transaction).to eq(new_transaction)
      end
    end

    describe '#expired?' do
      it 'returns true if expires_at is in the past' do
        attempt = build(:payment_attempt, expires_at: 1.hour.ago)
        expect(attempt.expired?).to be true
      end

      it 'returns false if expires_at is in the future' do
        attempt = build(:payment_attempt, expires_at: 1.hour.from_now)
        expect(attempt.expired?).to be false
      end

      it 'returns false if expires_at is nil' do
        attempt = build(:payment_attempt, expires_at: nil)
        expect(attempt.expired?).to be false
      end
    end

    describe 'status update methods' do
      let(:attempt) { create(:payment_attempt, status: 'created') }

      describe '#mark_as_captured!' do
        it 'updates status to captured' do
          attempt.mark_as_captured!
          expect(attempt.reload.status).to eq('captured')
        end
      end

      describe '#mark_as_failed!' do
        it 'updates status to failed' do
          attempt.mark_as_failed!
          expect(attempt.reload.status).to eq('failed')
        end
      end

      describe '#mark_as_pending!' do
        it 'updates status to pending' do
          attempt.mark_as_pending!
          expect(attempt.reload.status).to eq('pending')
        end
      end

      describe '#mark_as_authorized!' do
        it 'updates status to authorized' do
          attempt.mark_as_authorized!
          expect(attempt.reload.status).to eq('authorized')
        end
      end
    end
  end

  describe 'uniqueness' do
    it 'prevents duplicate razorpay_order_id' do
      attempt1 = create(:payment_attempt, razorpay_order_id: 'order_unique123')
      attempt2 = build(:payment_attempt, razorpay_order_id: 'order_unique123')
      
      expect(attempt2).not_to be_valid
      expect(attempt2.errors[:razorpay_order_id]).to include('has already been taken')
    end
  end
end
