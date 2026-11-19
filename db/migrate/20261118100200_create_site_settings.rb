class CreateSiteSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :site_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :site_settings, :key, unique: true
  end
end
