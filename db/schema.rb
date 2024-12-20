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

ActiveRecord::Schema[8.0].define(version: 2024_12_17_040556) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "calendar_plans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recipe_id", null: false
    t.date "date"
    t.string "meal_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "meal_plan"
    t.index ["recipe_id"], name: "index_calendar_plans_on_recipe_id"
    t.index ["user_id"], name: "index_calendar_plans_on_user_id"
  end

  create_table "foods", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.string "name", null: false
    t.string "unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_url"
    t.index ["recipe_id"], name: "index_foods_on_recipe_id"
  end

  create_table "nutritions", force: :cascade do |t|
    t.float "protein"
    t.float "fat"
    t.float "carbohydrates"
    t.float "vitamins"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "food_id", null: false
    t.float "mineral"
    t.float "protein_value"
    t.float "fat_value"
    t.float "carbohydrates_value"
    t.float "vitamins_value"
    t.float "mineral_value"
    t.index ["food_id"], name: "index_nutritions_on_food_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "calendar_plans", "recipes"
  add_foreign_key "calendar_plans", "users"
  add_foreign_key "foods", "recipes"
  add_foreign_key "nutritions", "foods"
end
