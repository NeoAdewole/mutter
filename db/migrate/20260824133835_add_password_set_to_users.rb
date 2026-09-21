class AddPasswordSetToUsers < ActiveRecord::Migration[7.2]
  def change
    # Tracks whether the user knows a real password for this account (set by them,
    # via registration, "add a password", or a password reset) as opposed to only
    # having the random password OmniAuth sign-up generates internally.
    # Defaults true so existing accounts (all created via the registration form
    # today) aren't affected; OAuth sign-up explicitly sets this to false.
    add_column :users, :password_set, :boolean, null: false, default: true
  end
end
