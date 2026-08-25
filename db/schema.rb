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

ActiveRecord::Schema[8.1].define(version: 2026_08_24_151000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "course_attendances", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["course_id"], name: "index_course_attendances_on_course_id"
    t.index ["user_id", "course_id"], name: "index_course_attendances_on_user_and_course", unique: true
    t.index ["user_id"], name: "index_course_attendances_on_user_id"
  end

  create_table "course_requirements", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.decimal "hours", precision: 6, scale: 2, null: false
    t.bigint "juleica_requirement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "juleica_requirement_id"], name: "index_course_requirements_on_course_and_requirement", unique: true
    t.index ["course_id"], name: "index_course_requirements_on_course_id"
    t.index ["juleica_requirement_id"], name: "index_course_requirements_on_juleica_requirement_id"
    t.check_constraint "hours > 0::numeric", name: "course_requirements_hours_positive"
  end

  create_table "courses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at", null: false
    t.string "location"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_courses_on_organization_id"
  end

  create_table "juleica_requirements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.decimal "required_hours", precision: 6, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_juleica_requirements_on_name", unique: true
    t.check_constraint "required_hours > 0::numeric", name: "juleica_requirements_required_hours_positive"
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "course_attendances", "courses"
  add_foreign_key "course_attendances", "users"
  add_foreign_key "course_requirements", "courses"
  add_foreign_key "course_requirements", "juleica_requirements"
  add_foreign_key "courses", "organizations"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
end
