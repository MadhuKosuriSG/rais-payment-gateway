# frozen_string_literal: true

FactoryBot.define do
  factory :payment_attempt do
    association :payment
    sequence(:razorpay_order_id) { |n| "order_test#{n.to_s.rjust(10, '0')}" }
    amount { 499.00 }
    currency { 'INR' }
    status { 'created' }
    razorpay_order_status { 'created' }
    attempt_number { 1 }
    expires_at { 15.minutes.from_now }

    trait :pending do
      status { 'pending' }
      razorpay_order_status { 'attempted' }
    end

    trait :authorized do
      status { 'authorized' }
      razorpay_order_status { 'authorized' }
    end

    trait :captured do
      status { 'captured' }
      razorpay_order_status { 'paid' }
    end

    trait :failed do
      status { 'failed' }
      razorpay_order_status { 'failed' }
    end

    trait :expired do
      status { 'expired' }
      expires_at { 1.hour.ago }
    end

    trait :second_attempt do
      attempt_number { 2 }
    end

    trait :with_transaction do
      after(:create) do |attempt|
        create(:gateway_transaction, payment_attempt: attempt)
      end
    end
  end
end
