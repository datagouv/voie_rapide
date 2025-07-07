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

ActiveRecord::Schema[8.0].define(version: 2025_07_07_155356) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "applications", force: :cascade do |t|
    t.string "siret", null: false
    t.string "company_name", null: false
    t.string "email"
    t.bigint "public_market_id", null: false
    t.datetime "submitted_at"
    t.string "attestation_path"
    t.string "dossier_zip_path"
    t.text "form_data"
    t.string "status", default: "in_progress", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_market_id", "siret"], name: "index_applications_on_public_market_id_and_siret", unique: true
    t.index ["public_market_id"], name: "index_applications_on_public_market_id"
    t.index ["siret"], name: "index_applications_on_siret"
    t.index ["status"], name: "index_applications_on_status"
    t.index ["submitted_at"], name: "index_applications_on_submitted_at"
  end

  create_table "documents", force: :cascade do |t|
    t.string "nom", null: false
    t.text "description"
    t.boolean "obligatoire", default: false, null: false
    t.string "categorie", null: false
    t.string "type_marche"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["categorie", "type_marche"], name: "index_documents_on_categorie_and_type_marche"
    t.index ["categorie"], name: "index_documents_on_categorie"
    t.index ["obligatoire"], name: "index_documents_on_obligatoire"
    t.index ["type_marche"], name: "index_documents_on_type_marche"
  end

  create_table "editors", force: :cascade do |t|
    t.string "name", null: false
    t.string "client_id", null: false
    t.string "client_secret", null: false
    t.string "callback_url", null: false
    t.boolean "authorized", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_editors_on_client_id", unique: true
    t.index ["name"], name: "index_editors_on_name", unique: true
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "public_market_configurations", force: :cascade do |t|
    t.bigint "public_market_id", null: false
    t.bigint "document_id", null: false
    t.boolean "required", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_public_market_configurations_on_document_id"
    t.index ["public_market_id", "document_id"], name: "idx_on_public_market_id_document_id_ae94b6a312", unique: true
    t.index ["public_market_id"], name: "index_public_market_configurations_on_public_market_id"
    t.index ["required"], name: "index_public_market_configurations_on_required"
  end

  create_table "public_markets", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.datetime "deadline", null: false
    t.string "fast_track_id", null: false
    t.string "market_type", null: false
    t.bigint "editor_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deadline"], name: "index_public_markets_on_deadline"
    t.index ["editor_id", "created_at"], name: "index_public_markets_on_editor_id_and_created_at"
    t.index ["editor_id"], name: "index_public_markets_on_editor_id"
    t.index ["fast_track_id"], name: "index_public_markets_on_fast_track_id", unique: true
  end

  add_foreign_key "applications", "public_markets"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "public_market_configurations", "documents"
  add_foreign_key "public_market_configurations", "public_markets"
  add_foreign_key "public_markets", "editors"
end
