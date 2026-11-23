# An append-only record of something an admin did. Rows are never edited or
# deleted through the app, and keep a snapshot of who and what (labels) so the
# history stays readable after the admin or the target has been removed.
class AuditLog < ApplicationRecord
  ACTIONS = {
    'user.updated' => 'Edited a user',
    'user.admin_granted' => 'Made a user an admin',
    'user.admin_revoked' => 'Removed admin rights',
    'user.suspended' => 'Suspended a user',
    'user.unsuspended' => 'Restored a suspended user',
    'user.deleted' => 'Deleted a user',
    'user.password_reset_sent' => 'Sent a password reset email',
    'user.identity_disconnected' => "Disconnected a user's linked account",
    'page.created' => 'Created a page',
    'page.updated' => 'Edited a page',
    'page.published' => 'Published a page',
    'page.unpublished' => 'Unpublished a page',
    'page.moved' => 'Reordered a page',
    'page.deleted' => 'Deleted a page',
    'page.block_added' => 'Added a block to a page',
    'page.block_updated' => 'Edited a block on a page',
    'page.block_moved' => "Reordered a page's blocks",
    'page.block_removed' => 'Removed a block from a page',
    'settings.updated' => 'Changed site settings',
    'system.cache_cleared' => 'Cleared the application cache'
  }.freeze

  belongs_to :actor, class_name: 'User', optional: true

  validates :action, inclusion: { in: ACTIONS.keys }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :for_action, ->(action) { where(action: action) }
  # Entries where this record was the target of an action, or the admin who took it.
  scope :involving, lambda { |record|
    where(target_type: record.class.name, target_id: record.id).or(where(actor_id: record.id))
  }

  # Records one action. `target` may be a record or nil; its label is captured
  # now, because it may not exist later (a deleted record can still be passed in:
  # its attributes are still in memory).
  def self.record(actor:, action:, target: nil, details: {}, ip_address: nil)
    create!(
      actor: actor,
      actor_label: actor && AuditLog.label_for(actor),
      action: action,
      target_type: target&.class&.name,
      target_id: target&.id,
      target_label: target && label_for(target),
      details: details,
      ip_address: ip_address
    )
  end

  def self.label_for(record)
    record.respond_to?(:audit_label) ? record.audit_label : "#{record.class.name} ##{record.id}"
  end

  def summary
    ACTIONS.fetch(action, action)
  end

  # Entries are history: once written they can't be changed or removed.
  def readonly?
    !new_record? || super
  end
end
