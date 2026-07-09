# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_07_08_000002) do
  create_table "models", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rides", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "tram_id", null: false
    t.integer "line", null: false
    t.date "ridden_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tram_id"], name: "index_rides_on_tram_id"
    t.index ["user_id"], name: "index_rides_on_user_id"
  end

  create_table "trams", force: :cascade do |t|
    t.string "number", null: false
    t.string "name"
    t.text "description"
    t.integer "model_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_trams_on_model_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "is_admin", default: false, null: false
    t.boolean "password_set", default: true, null: false
    t.string "api_token"
    t.string "google_uid"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
  end

  add_foreign_key "rides", "trams"
  add_foreign_key "rides", "users"
  add_foreign_key "trams", "models"
end
