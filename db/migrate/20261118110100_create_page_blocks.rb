# A page is a stack of blocks (carousel, row of cards, text). Blocks have a few
# settings of their own; carousels and card rows also hold ordered items
# (slides / cards). Deleting a page deletes its blocks, and a block its items.
class CreatePageBlocks < ActiveRecord::Migration[7.2]
  def change
    create_table :page_blocks do |t|
      t.references :page, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.integer :position, null: false, default: 0
      t.string :heading, null: false, default: ''
      t.text :body, null: false, default: ''
      t.integer :columns, null: false, default: 3
      t.boolean :show_live_streams, null: false, default: false
      t.timestamps
    end
    add_index :page_blocks, %i[page_id position]
  end
end
