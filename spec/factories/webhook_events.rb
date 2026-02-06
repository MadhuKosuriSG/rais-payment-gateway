# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_event do
    sequence(:event_id) { |n| "event_test#{n.to_s.rjust(10, '0')}" }
    event_type { 'payment.captured' }
    razorpay_payment_id { 'pay_test0000000001' }
    razorpay_order_id { 'order_test0000000001' }
    signature { 'test_signature_123' }
    processed { false }
    
    payload do
      {
        'event' => event_type,
        'payload' => {
          'payment' => {
            'entity' => {
              'id' => razorpay_payment_id,
              'order_id' => razorpay_order_id,
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

    trait :processed do
      processed { true }
      processed_at { Time.current }
    end

    trait :failed_processing do
      processed { false }
      processing_error { 'Payment attempt not found' }
    end

    trait :payment_failed do
      event_type { 'payment.failed' }
      
      payload do
        {
          'event' => 'payment.failed',
          'payload' => {
            'payment' => {
              'entity' => {
                'id' => razorpay_payment_id,
                'order_id' => razorpay_order_id,
                'amount' => 49900,
                'currency' => 'INR',
                'status' => 'failed',
                'method' => 'card',
                'email' => 'customer@example.com',
                'contact' => '+919876543210',
                'error_code' => 'BAD_REQUEST_ERROR',
                'error_description' => 'Payment failed',
                'created_at' => Time.current.to_i
              }
            }
          }
        }
      end
    end

    trait :payment_authorized do
      event_type { 'payment.authorized' }
      
      payload do
        {
          'event' => 'payment.authorized',
          'payload' => {
            'payment' => {
              'entity' => {
                'id' => razorpay_payment_id,
                'order_id' => razorpay_order_id,
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
    end
  end
end
