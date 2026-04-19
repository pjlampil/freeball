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

ActiveRecord::Schema[8.1].define(version: 2026_04_19_205049) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "frames", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "first_to_break_id"
    t.integer "frame_number", null: false
    t.bigint "match_id", null: false
    t.datetime "paused_at"
    t.bigint "pending_winner_id"
    t.datetime "reds_cleared_at"
    t.integer "removed_reds", default: 0, null: false
    t.boolean "respotted_black", default: false, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "total_paused_seconds", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "winner_id"
    t.index ["first_to_break_id"], name: "index_frames_on_first_to_break_id"
    t.index ["match_id"], name: "index_frames_on_match_id"
    t.index ["pending_winner_id"], name: "index_frames_on_pending_winner_id"
    t.index ["winner_id"], name: "index_frames_on_winner_id"
  end

  create_table "matches", force: :cascade do |t|
    t.integer "best_of"
    t.datetime "created_at", null: false
    t.bigint "current_frame_id"
    t.integer "match_format", default: 0, null: false
    t.bigint "player1_id", null: false
    t.bigint "player2_id", null: false
    t.integer "scoring_mode", default: 0, null: false
    t.bigint "snooker_table_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "venue_id"
    t.integer "visit_mode", default: 0, null: false
    t.index ["player1_id"], name: "index_matches_on_player1_id"
    t.index ["player2_id"], name: "index_matches_on_player2_id"
    t.index ["snooker_table_id"], name: "index_matches_on_snooker_table_id"
    t.index ["venue_id"], name: "index_matches_on_venue_id"
  end

  create_table "shots", force: :cascade do |t|
    t.integer "ball"
    t.datetime "created_at", null: false
    t.integer "foul_value"
    t.integer "points"
    t.integer "result"
    t.integer "sequence"
    t.datetime "updated_at", null: false
    t.bigint "visit_id", null: false
    t.index ["visit_id"], name: "index_shots_on_visit_id"
  end

  create_table "snooker_tables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "number"
    t.datetime "updated_at", null: false
    t.bigint "venue_id", null: false
    t.index ["venue_id"], name: "index_snooker_tables_on_venue_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.boolean "superuser", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "visits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "ended_by"
    t.bigint "frame_id", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.integer "visit_number", null: false
    t.index ["frame_id"], name: "index_visits_on_frame_id"
    t.index ["player_id"], name: "index_visits_on_player_id"
  end

  add_foreign_key "frames", "matches"
  add_foreign_key "frames", "users", column: "first_to_break_id"
  add_foreign_key "frames", "users", column: "pending_winner_id"
  add_foreign_key "frames", "users", column: "winner_id"
  add_foreign_key "matches", "snooker_tables"
  add_foreign_key "matches", "users", column: "player1_id"
  add_foreign_key "matches", "users", column: "player2_id"
  add_foreign_key "matches", "venues"
  add_foreign_key "shots", "visits"
  add_foreign_key "snooker_tables", "venues"
  add_foreign_key "visits", "frames"
  add_foreign_key "visits", "users", column: "player_id"
end
