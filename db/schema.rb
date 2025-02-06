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

ActiveRecord::Schema[8.0].define(version: 2025_02_04_134530) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.float "amount"
    t.string "category"
    t.boolean "editable", default: true
    t.json "custom_nutrition"
    t.index ["recipe_id"], name: "index_foods_on_recipe_id"
  end

  create_table "main_images", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nutritions", force: :cascade do |t|
    t.float "protein"
    t.float "fat"
    t.float "carbohydrates"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "vitamins"
    t.json "minerals"
    t.bigint "recipe_id", null: false
    t.float "energy"
    t.float "fiber"
    t.float "vitamin_a"
    t.float "vitamin_b1"
    t.float "vitamin_b2"
    t.float "vitamin_c"
    t.float "vitamin_d"
    t.float "vitamin_e"
    t.float "calcium"
    t.float "iron"
    t.float "zinc"
    t.float "magnesium"
    t.index ["recipe_id"], name: "index_nutritions_on_recipe_id"
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
    t.string "nickname"
    t.integer "age"
    t.string "gender"
    t.string "provider"
    t.string "uid"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calendar_plans", "recipes"
  add_foreign_key "calendar_plans", "users"
  add_foreign_key "foods", "recipes"
  add_foreign_key "nutritions", "recipes"
end
