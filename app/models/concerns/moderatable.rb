# What the admin area needs from a User: ways to find and order people, and
# suspending (and restoring) an account. Kept apart from User so the model that
# handles sign-in and identities stays readable.
module Moderatable
  extend ActiveSupport::Concern

  # Orderings offered by the admin user list: key => [label, SQL].
  SORTS = {
    'newest' => ['Newest first', 'users.created_at DESC, users.id DESC'],
    'oldest' => ['Oldest first', 'users.created_at ASC, users.id ASC'],
    'username' => ['Username A–Z', 'lower(users.username) ASC, users.id ASC'],
    'recent_sign_in' => ['Recently signed in', 'users.last_sign_in_at DESC NULLS LAST, users.id DESC']
  }.freeze

  included do
    validates :suspension_reason, length: { maximum: 500 }

    scope :admins, -> { where(admin: true) }
    scope :regular, -> { where(admin: false) }
    scope :suspended, -> { where.not(suspended_at: nil) }
    scope :active, -> { where(suspended_at: nil) }
    scope :with_provider, ->(provider) { where(id: Identity.where(provider: provider).select(:user_id)) }
    scope :sorted_by, ->(key) { order(Arel.sql(SORTS.fetch(key.to_s) { SORTS.fetch('newest') }.last)) }
  end

  class_methods do
    # Case-insensitive match on username, email or name. LIKE wildcards typed by
    # the admin are matched literally.
    def search(term)
      term = term.to_s.strip
      return all if term.empty?

      pattern = "%#{sanitize_sql_like(term.downcase)}%"
      where(
        'lower(users.username) LIKE :p OR lower(users.email) LIKE :p OR lower(users.firstname) LIKE :p OR lower(users.lastname) LIKE :p',
        p: pattern
      )
    end
  end

  def suspended?
    suspended_at.present?
  end

  def suspend!(reason: nil)
    update!(suspended_at: Time.current, suspension_reason: reason.to_s.strip.presence)
  end

  def unsuspend!
    update!(suspended_at: nil, suspension_reason: nil)
  end
end
