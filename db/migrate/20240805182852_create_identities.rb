class CreateIdentities < ActiveRecord::Migration[7.2]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :uuid

      t.timestamps
    end
  end
end
