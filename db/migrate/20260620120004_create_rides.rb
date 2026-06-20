class CreateRides < ActiveRecord::Migration[7.1]
  def change
    create_table :rides do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tram, null: false, foreign_key: true
      t.integer    :line, null: false
      t.date       :ridden_on, null: false
      t.timestamps
    end
  end
end
