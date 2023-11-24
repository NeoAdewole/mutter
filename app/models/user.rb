class User < ApplicationRecord
  has_many :twitter_accounts

  has_secure_password

  validates :email, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\z/, message: "Must be a valid email address." }
  validates :email, uniqueness: true
  normalizes :email, with: ->(email) {email.strip.downcase}

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end
  
  # Example for email confirmation process
  # generates_token_for :email_confirmation, expires_in: 24.hours do
  #   email
  # end

end