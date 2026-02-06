# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    sequence(:public_reference) { |n| "PAY_TEST#{n.to_s.rjust(8, '0')}" }
    sequence(:idempotency_key) { |n| "idempotency-key-#{n}-#{SecureRandom.uuid}" }
    amount { 499.00 }
    currency { 'INR' }
    status { 'created' }
    metadata { { product_id: 1, user_email: 'test@example.com' } }

    trait :initiated do
      status { 'initiated' }
    end

    trait :pending do
      status { 'pending' }
    end

    trait :captured do
      status { 'captured' }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    trait :with_user do
      user_id { 1 }
    end

    trait :with_attempts do
      after(:create) do |payment|
        create(:payment_attempt, payment: payment)
      end
    end

    trait :with_successful_transaction do
      after(:create) do |payment|
        attempt = create(:payment_attempt, :captured, payment: payment)
        create(:gateway_transaction, :captured, payment_attempt: attempt)
      end
    end
  end
end
