class AddPasswordSetToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :password_set, :boolean, null: false, default: true
    # All users that exist at this point have placeholder passwords from the
    # backfill migration — mark them as unclaimed so they go through the
    # claim-account flow on first login.
    User.update_all(password_set: false)
  end

  def down
    remove_column :users, :password_set
  end
end
