class CreateTrams < ActiveRecord::Migration[7.1]
  def change
    create_table :trams do |t|
      t.string :number, null: false
      t.string :name
      t.text   :description
      t.references :model, null: false, foreign_key: true
      t.timestamps
    end
  end
end
