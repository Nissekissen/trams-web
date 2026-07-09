class AddIndexToGoogleUid < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :google_uid, unique: true
  end
end
