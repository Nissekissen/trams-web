class AddAppleUidToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :apple_uid, :string
  end
end
