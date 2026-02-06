# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow requests from your frontend URL
    # In production, replace with your actual frontend domain
    origins ENV.fetch('FRONTEND_URL', 'http://localhost:3001'), 'http://localhost:3000'

    # Payment API endpoints
    resource '/payments/*',
      headers: :any,
      methods: [:get, :post, :options],
      credentials: false

    # Health check
    resource '/health',
      headers: :any,
      methods: [:get, :options]

    # API docs
    resource '/api/docs',
      headers: :any,
      methods: [:get, :options]
  end

  # Webhooks should accept requests from Razorpay servers
  allow do
    origins '*' # Razorpay servers can be from any IP

    resource '/webhooks/*',
      headers: :any,
      methods: [:post, :options]
  end
end
