# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_02_04_000004) do
  create_table "gateway_transactions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "payment_attempt_id", null: false
    t.string "razorpay_payment_id", null: false
    t.string "razorpay_order_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", limit: 3, default: "INR", null: false
    t.string "status", limit: 50, null: false
    t.string "method", limit: 50
    t.string "card_last4", limit: 4
    t.string "card_network", limit: 20
    t.string "bank", limit: 100
    t.string "email"
    t.string "contact", limit: 15
    t.decimal "fee", precision: 10, scale: 2
    t.decimal "tax", precision: 10, scale: 2
    t.string "error_code", limit: 100
    t.text "error_description"
    t.datetime "captured_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_gateway_transactions_on_created_at"
    t.index ["payment_attempt_id"], name: "index_gateway_transactions_on_payment_attempt_id"
    t.index ["razorpay_order_id"], name: "index_gateway_transactions_on_razorpay_order_id"
    t.index ["razorpay_payment_id"], name: "index_gateway_transactions_on_razorpay_payment_id", unique: true
    t.index ["status"], name: "index_gateway_transactions_on_status"
  end

  create_table "payment_attempts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.string "razorpay_order_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", limit: 3, default: "INR", null: false
    t.string "status", limit: 20, default: "created", null: false
    t.string "razorpay_order_status", limit: 50
    t.integer "attempt_number", default: 1, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id", "attempt_number"], name: "index_payment_attempts_on_payment_id_and_attempt_number"
    t.index ["payment_id"], name: "index_payment_attempts_on_payment_id"
    t.index ["razorpay_order_id"], name: "index_payment_attempts_on_razorpay_order_id", unique: true
    t.index ["status"], name: "index_payment_attempts_on_status"
  end

  create_table "payments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "public_reference", limit: 64, null: false
    t.string "idempotency_key", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", limit: 3, default: "INR", null: false
    t.string "status", limit: 20, default: "created", null: false
    t.bigint "user_id"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_payments_on_idempotency_key", unique: true
    t.index ["public_reference"], name: "index_payments_on_public_reference", unique: true
    t.index ["status", "created_at"], name: "index_payments_on_status_and_created_at"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "webhook_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_id", null: false
    t.string "event_type", limit: 100, null: false
    t.string "razorpay_payment_id"
    t.string "razorpay_order_id"
    t.json "payload", null: false
    t.string "signature", null: false
    t.boolean "processed", default: false, null: false
    t.datetime "processed_at"
    t.text "processing_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_webhook_events_on_created_at"
    t.index ["event_id"], name: "index_webhook_events_on_event_id", unique: true
    t.index ["event_type"], name: "index_webhook_events_on_event_type"
    t.index ["processed", "created_at"], name: "index_webhook_events_on_processed_and_created_at"
    t.index ["processed"], name: "index_webhook_events_on_processed"
    t.index ["razorpay_order_id"], name: "index_webhook_events_on_razorpay_order_id"
    t.index ["razorpay_payment_id"], name: "index_webhook_events_on_razorpay_payment_id"
  end

  add_foreign_key "gateway_transactions", "payment_attempts"
  add_foreign_key "payment_attempts", "payments"
end
