Rails.application.routes.draw do
  # Health check endpoint
  get '/health', to: proc { [200, {}, ['OK']] }
  
  # Payment routes
  resources :payments, only: [:create, :show] do
    member do
      post :create_order
    end
  end
  
  # Webhook routes
  namespace :webhooks do
    post :razorpay
  end
  
  # API documentation route (optional)
  get '/api/docs', to: proc { 
    [200, { 'Content-Type' => 'application/json' }, [
      {
        endpoints: {
          payments: {
            create: 'POST /payments',
            show: 'GET /payments/:id',
            create_order: 'POST /payments/:id/create_order'
          },
          webhooks: {
            razorpay: 'POST /webhooks/razorpay'
          }
        }
      }.to_json
    ]]
  }
end

