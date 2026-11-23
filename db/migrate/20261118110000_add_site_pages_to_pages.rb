# Home, About and the four section landing pages are pages too, so admins can
# edit them. They sit outside the four sections' trees: they have a system_key
# instead of a section, and the key is unique.
class AddSitePagesToPages < ActiveRecord::Migration[7.2]
  def change
    change_column_null :pages, :section, true
    add_column :pages, :system_key, :string
    add_column :pages, :show_title, :boolean, default: true, null: false
    add_index :pages, :system_key, unique: true
    add_check_constraint :pages, 'section IS NOT NULL OR system_key IS NOT NULL', name: 'pages_belong_somewhere'
  end
end
