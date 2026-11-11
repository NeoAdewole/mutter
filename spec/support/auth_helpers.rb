# Logs a user in through the real password form, for request specs.
module AuthHelpers
  def sign_in_as(user, password: 'password123')
    post session_path, params: { user: { email: user.email, password: password } }
  end

  def html
    Nokogiri::HTML(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
