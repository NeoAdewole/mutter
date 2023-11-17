class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :Firstname
      t.string :Lastname
      t.string :Alias

      t.timestamps
    end
  end
end
