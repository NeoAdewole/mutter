class AddUsernameToIdentities < ActiveRecord::Migration[7.2]
  def change
    add_column :identities, :username, :string
  end
end
