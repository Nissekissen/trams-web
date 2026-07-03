class AddIndexToApiToken < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :api_token, unique: true
  end
end
