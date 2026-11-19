class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      # Who did it. Nullable (and nullified, not cascaded) so deleting an admin
      # never deletes the record of what they did; actor_label keeps their name.
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :actor_label
      t.string :action, null: false
      # What it was done to. No foreign key: the target may since have been deleted,
      # which is exactly when the record matters most. target_label is a snapshot.
      t.string :target_type
      t.bigint :target_id
      t.string :target_label
      t.jsonb :details, null: false, default: {}
      t.string :ip_address
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :created_at
    add_index :audit_logs, :action
    add_index :audit_logs, %i[target_type target_id]
  end
end
