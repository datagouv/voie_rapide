# frozen_string_literal: true

# Shared examples for common test patterns
RSpec.shared_examples 'redirects to login' do
  it 'redirects to login' do
    expect(response).to have_http_status(:redirect)
  end
end

RSpec.shared_examples 'requires authentication' do
  it 'requires authentication' do
    expect(response).to have_http_status(:unauthorized)
  end
end
