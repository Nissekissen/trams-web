class AddAuthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :email, :string
    add_column :users, :password_digest, :string
    add_column :users, :is_admin, :boolean, null: false, default: false
    add_index :users, :email, unique: true
  end
end
