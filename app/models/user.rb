class User < ApplicationRecord
  has_secure_password

  has_many :identities, dependent: :destroy
  has_many :twitter_accounts, dependent: :destroy
  has_many :tweets, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :firstname, presence: true
  validates :lastname, presence: true
  # The Mutter username is one namespace for everyone, unlike a provider handle
  # (which only has to be unique on its own service), and is compared ignoring case.
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, on: :create
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :password_confirmation, presence: true, on: :create

  normalizes :email, with: ->(email) { email.strip.downcase }

  include Moderatable

  SORTS = Moderatable::SORTS

  # Accounts without a real email get this placeholder until their owner adds one.
  PLACEHOLDER_EMAIL_DOMAIN = 'users.mutter.local'.freeze

  # Counted at every successful sign-in, by any method, for the admin's overview.
  def record_sign_in!
    update_columns(last_sign_in_at: Time.current, sign_in_count: sign_in_count + 1)
  end

  def placeholder_email?
    email.to_s.end_with?("@#{PLACEHOLDER_EMAIL_DOMAIN}")
  end

  def full_name
    [firstname, lastname].compact_blank.join(' ')
  end

  # How this user is named in the audit log (kept even after they are deleted).
  def audit_label
    "#{username} <#{email}>"
  end

  # Could they still sign in if this identity were disconnected? Used so an admin
  # can't strand an account that only has the one way in.
  def can_sign_in_without?(identity)
    password_set? || identities.where.not(id: identity.id).where.not(provider: Identity::CONNECT_ONLY_PROVIDERS).exists?
  end

  def self.find_or_create_from_auth_hash(auth_hash)
    identity = Identity.find_or_create_by(provider: auth_hash.provider, uuid: auth_hash.uid)
    handle = ProviderHandle.for(auth_hash)

    if identity.user.present?
      identity.refresh_handle(handle)
      identity.user
    else
      user = user_for_new_identity(auth_hash)
      identity.update(user:, username: handle)
      user
    end
  end

  # Would signing in with this provider identity reach an account that already
  # exists (rather than create one)? Used to pause sign-ups without locking out members.
  def self.account_exists_for?(auth_hash)
    return true if Identity.exists?(provider: auth_hash.provider, uuid: auth_hash.uid)

    email = auth_hash.info.email.presence
    email.present? && exists?(email: email)
  end

  # The existing account whose email matches, or a brand-new one built from
  # what the provider told us.
  def self.user_for_new_identity(auth_hash)
    email = auth_hash.info.email.presence
    user = email ? User.find_or_initialize_by(email: email) : User.new
    return user unless user.new_record?

    assign_profile(user, auth_hash, email)
    assign_generated_password(user)
    user.save!
    user
  end

  # The Mutter username starts from the provider's handle but is its own thing:
  # it is only ever *derived* from the handle, and made unique, because two
  # different people can legitimately have the same handle on different services.
  def self.assign_profile(user, auth_hash, email)
    # info['name'], not info.name: OmniAuth's InfoHash#name quietly falls back to the
    # nickname and then the email address when the provider sent no name.
    full_name = auth_hash.info['name'].to_s
    base = auth_hash.info.nickname.presence || full_name.presence || email.to_s.split('@').first.presence || 'user'
    name_parts = full_name.split(' ', 2)
    user.firstname = name_parts.first.presence || base
    user.lastname  = name_parts.last.presence  || base
    user.username = available_username(base)
    # Some providers (or scopes) don't return an email at all. We still
    # need a valid, unique one to persist the record, so stand up a
    # placeholder; the controller sends the user straight to their
    # profile to replace it with a real address.
    user.email ||= "pending-#{SecureRandom.hex(8)}@#{PLACEHOLDER_EMAIL_DOMAIN}"
  end

  def self.assign_generated_password(user)
    generated_password = SecureRandom.hex(15)
    user.password = generated_password
    user.password_confirmation = generated_password
    # They don't know this generated password, so this account doesn't
    # count as having a real, usable password yet.
    user.password_set = false
  end

  # base, or base2, base3... if it's taken (ignoring case).
  def self.available_username(base)
    candidate = base
    suffix = 1
    while exists?(['lower(username) = ?', candidate.downcase])
      suffix += 1
      candidate = "#{base}#{suffix}"
    end
    candidate
  end
  private_class_method :user_for_new_identity, :assign_profile, :assign_generated_password, :available_username

  # Links a provider identity to THIS already-known, already-logged-in user,
  # as opposed to find_or_create_from_auth_hash's job of figuring out who to
  # log in as. Never reassigns an identity that belongs to someone else.
  #
  # Returns :connected, :already_connected (to this same user), or
  # :conflict (belongs to a different user).
  def connect_identity_from_auth_hash(auth_hash)
    identity = Identity.find_or_create_by(provider: auth_hash.provider, uuid: auth_hash.uid)
    handle = ProviderHandle.for(auth_hash)

    if identity.user_id == id
      identity.refresh_handle(handle)
      return :already_connected
    end
    return :conflict if identity.user_id.present?

    identity.update!(user: self, username: handle)
    :connected
  end
end
