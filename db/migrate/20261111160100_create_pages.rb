class CreatePages < ActiveRecord::Migration[7.2]
  def change
    create_table :pages do |t|
      t.string :section, null: false
      t.references :parent, foreign_key: { to_table: :pages }, null: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body, null: false, default: ''
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    # Slugs only need to be unique among siblings. Postgres treats NULLs as
    # distinct, so top-level pages (parent_id NULL) get their own partial index.
    add_index :pages, %i[section parent_id slug], unique: true, name: 'index_pages_on_siblings_slug'
    add_index :pages, %i[section slug], unique: true, where: 'parent_id IS NULL', name: 'index_pages_on_top_level_slug'
    add_index :pages, %i[section parent_id position], name: 'index_pages_on_ordering'
  end
end
