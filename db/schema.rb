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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "contents", force: :cascade do |t|
    t.integer "content_type", null: false
    t.datetime "created_at", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["content_type"], name: "index_contents_on_content_type"
    t.index ["parent_id"], name: "index_contents_on_parent_id"
    t.index ["position"], name: "index_contents_on_position"
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_organization_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "program_attendances", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "program_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_program_attendances_on_program_id"
    t.index ["user_id", "program_id"], name: "index_program_attendances_on_user_id_and_program_id", unique: true
    t.index ["user_id"], name: "index_program_attendances_on_user_id"
  end

  create_table "programs", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "organization_id", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_programs_on_kind"
    t.index ["organization_id"], name: "index_programs_on_organization_id"
  end

  create_table "unit_attendances", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["unit_id"], name: "index_unit_attendances_on_unit_id"
    t.index ["user_id", "unit_id"], name: "index_unit_attendances_on_user_and_unit", unique: true
    t.index ["user_id"], name: "index_unit_attendances_on_user_id"
  end

  create_table "unit_coverages", force: :cascade do |t|
    t.bigint "content_id", null: false
    t.bigint "unit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_unit_coverages_on_content_id"
    t.index ["unit_id", "content_id"], name: "index_unit_coverages_on_unit_and_content", unique: true
    t.index ["unit_id"], name: "index_unit_coverages_on_unit_id"
  end

  create_table "units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at"
    t.string "location"
    t.string "name", null: false
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.bigint "program_id", null: false
    t.bigint "instructor_id"
    t.index ["instructor_id"], name: "index_units_on_instructor_id"
    t.index ["program_id"], name: "index_units_on_program_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "locale", default: "de", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "contents", "contents", column: "parent_id"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "program_attendances", "programs"
  add_foreign_key "program_attendances", "users"
  add_foreign_key "programs", "organizations"
  add_foreign_key "unit_attendances", "units"
  add_foreign_key "unit_attendances", "users"
  add_foreign_key "unit_coverages", "contents"
  add_foreign_key "unit_coverages", "units"
  add_foreign_key "units", "programs"
  add_foreign_key "units", "users", column: "instructor_id"
end
