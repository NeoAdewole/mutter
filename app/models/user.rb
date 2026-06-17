class User < ApplicationRecord
  has_secure_password

  has_many :identities, dependent: :destroy
  has_many :twitter_accounts, dependent: :destroy
  has_many :tweets, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :firstname, presence: true
  validates :lastname, presence: true
  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :password_confirmation, presence: true, on: :create

  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  def self.find_or_create_from_auth_hash(auth_hash)
    identity = Identity.find_or_create_by(provider: auth_hash.provider, uuid: auth_hash.uid)

    if identity.user.present?
      identity.user
    else
      user = User.find_or_initialize_by(email: auth_hash.info.email)

      if user.new_record?
        name_parts = auth_hash.info.name.to_s.split(' ', 2)
        user.firstname = name_parts.first.presence || auth_hash.info.nickname
        user.lastname  = name_parts.last.presence  || auth_hash.info.nickname
        user.username              = auth_hash.info.nickname || auth_hash.info.name
        generated_password         = SecureRandom.hex(15)
        user.password              = generated_password
        user.password_confirmation = generated_password
        user.save!
      end

      identity.update(user:)
      user
    end
  end
end
