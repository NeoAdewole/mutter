# A slide in a carousel or a card in a row of cards. A card can feature an
# existing page; if that page is deleted the card keeps whatever it has of its
# own (the foreign key is nulled, never cascaded).
class CreateBlockItems < ActiveRecord::Migration[7.2]
  def change
    create_table :block_items do |t|
      t.references :page_block, null: false, foreign_key: { on_delete: :cascade }
      t.references :featured_page, foreign_key: { to_table: :pages, on_delete: :nullify }
      t.integer :position, null: false, default: 0
      t.string :title, null: false, default: ''
      t.text :body, null: false, default: ''
      t.string :image_url, null: false, default: ''
      t.string :alt_text, null: false, default: ''
      t.string :link_label, null: false, default: ''
      t.string :link_url, null: false, default: ''
      t.timestamps
    end
    add_index :block_items, %i[page_block_id position]
  end
end
