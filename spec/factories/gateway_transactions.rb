# frozen_string_literal: true

FactoryBot.define do
  factory :gateway_transaction do
    association :payment_attempt
    sequence(:razorpay_payment_id) { |n| "pay_test#{n.to_s.rjust(10, '0')}" }
    razorpay_order_id { payment_attempt&.razorpay_order_id || "order_test0000000001" }
    amount { 499.00 }
    currency { 'INR' }
    status { 'created' }
    add_attribute(:method) { 'card' }
    card_last4 { '1111' }
    card_network { 'Visa' }
    email { 'customer@example.com' }
    contact { '+919876543210' }

    trait :captured do
      status { 'captured' }
      fee { 9.90 }
      tax { 1.80 }
      captured_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      error_code { 'BAD_REQUEST_ERROR' }
      error_description { 'Payment failed due to insufficient funds' }
    end

    trait :authorized do
      status { 'authorized' }
    end

    trait :upi do
      add_attribute(:method) { 'upi' }
      card_last4 { nil }
      card_network { nil }
    end

    trait :netbanking do
      add_attribute(:method) { 'netbanking' }
      bank { 'HDFC Bank' }
      card_last4 { nil }
      card_network { nil }
    end

    trait :wallet do
      add_attribute(:method) { 'wallet' }
      card_last4 { nil }
      card_network { nil }
    end
  end
end
