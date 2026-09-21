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

  def self.find_or_create_from_auth_hash(auth_hash)
    identity = Identity.find_or_create_by(provider: auth_hash.provider, uuid: auth_hash.uid)

    if identity.user.present?
      identity.user
    else
      email = auth_hash.info.email.presence
      user = email ? User.find_or_initialize_by(email: email) : User.new

      if user.new_record?
        name_parts = auth_hash.info.name.to_s.split(' ', 2)
        user.firstname = name_parts.first.presence || auth_hash.info.nickname
        user.lastname  = name_parts.last.presence  || auth_hash.info.nickname
        user.username = auth_hash.info.nickname || auth_hash.info.name
        # Some providers (or scopes) don't return an email at all. We still
        # need a valid, unique one to persist the record, so stand up a
        # placeholder; the controller sends the user straight to their
        # profile to replace it with a real address.
        user.email ||= "pending-#{SecureRandom.hex(8)}@users.mutter.local"
        generated_password         = SecureRandom.hex(15)
        user.password              = generated_password
        user.password_confirmation = generated_password
        # They don't know this generated password, so this account doesn't
        # count as having a real, usable password yet.
        user.password_set          = false
        user.save!
      end

      identity.update(user:)
      user
    end
  end

  # Links a provider identity to THIS already-known, already-logged-in user,
  # as opposed to find_or_create_from_auth_hash's job of figuring out who to
  # log in as. Never reassigns an identity that belongs to someone else.
  #
  # Returns :connected, :already_connected (to this same user), or
  # :conflict (belongs to a different user).
  def connect_identity_from_auth_hash(auth_hash)
    identity = Identity.find_or_create_by(provider: auth_hash.provider, uuid: auth_hash.uid)

    return :already_connected if identity.user_id == id
    return :conflict if identity.user_id.present?

    identity.update!(user: self)
    :connected
  end
end
