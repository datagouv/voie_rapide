# frozen_string_literal: true

# Configure CORS for cross-origin requests from editor apps
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow requests from the editor app
    origins ENV.fetch('EDITOR_APP_URL', 'http://localhost:4000')

    # Allow all resources with appropriate headers
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             expose: %w[Authorization]
  end

  # Production configuration would be more restrictive
  if Rails.env.production?
    allow do
      origins ENV.fetch('ALLOWED_ORIGINS', '').split(',')
      resource '/api/*',
               headers: :any,
               methods: %i[get post put patch delete options head],
               credentials: true
    end
  end
end
