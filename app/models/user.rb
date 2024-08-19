class User < ApplicationRecord
  has_secure_password

  has_many :identities, dependent: :destroy
  has_many :twitter_accounts
  has_many :tweets

  validates :email, uniqueness: true, allow_nil: true
  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  # Method to find or create user from omniauth data
  def self.find_or_create_from_auth_hash(auth_hash)
    identity = Identity.find_or_create_by(provider: auth_hash.provider, uuid: auth_hash.uid)
    # TODO: Handle edge cases and saving a user from omni auth params
    if identity.user.present?
      identity.user
    else
      user = User.find_or_initialize_by(email: auth_hash.info.email)
      if user.new_record?
        user.username = auth_hash.info.nickname || auth_hash.info.name
        user.password = SecureRandom.hex(15)
        user.save!
      end
      identity.update(user:)
      user
    end
  end

  # Example for email confirmation process
  # generates_token_for :email_confirmation, expires_in: 24.hours do
  #   email
  # end
end
