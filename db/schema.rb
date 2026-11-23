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

ActiveRecord::Schema[7.2].define(version: 20_261_118_110_200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'audit_logs', force: :cascade do |t|
    t.bigint 'actor_id'
    t.string 'actor_label'
    t.string 'action', null: false
    t.string 'target_type'
    t.bigint 'target_id'
    t.string 'target_label'
    t.jsonb 'details', default: {}, null: false
    t.string 'ip_address'
    t.datetime 'created_at', null: false
    t.index ['action'], name: 'index_audit_logs_on_action'
    t.index ['actor_id'], name: 'index_audit_logs_on_actor_id'
    t.index ['created_at'], name: 'index_audit_logs_on_created_at'
    t.index %w[target_type target_id], name: 'index_audit_logs_on_target_type_and_target_id'
  end

  create_table 'block_items', force: :cascade do |t|
    t.bigint 'page_block_id', null: false
    t.bigint 'featured_page_id'
    t.integer 'position', default: 0, null: false
    t.string 'title', default: '', null: false
    t.text 'body', default: '', null: false
    t.string 'image_url', default: '', null: false
    t.string 'alt_text', default: '', null: false
    t.string 'link_label', default: '', null: false
    t.string 'link_url', default: '', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['featured_page_id'], name: 'index_block_items_on_featured_page_id'
    t.index %w[page_block_id position], name: 'index_block_items_on_page_block_id_and_position'
    t.index ['page_block_id'], name: 'index_block_items_on_page_block_id'
  end

  create_table 'identities', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.string 'provider'
    t.string 'uuid'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'username'
    t.index ['user_id'], name: 'index_identities_on_user_id'
  end

  create_table 'page_blocks', force: :cascade do |t|
    t.bigint 'page_id', null: false
    t.string 'kind', null: false
    t.integer 'position', default: 0, null: false
    t.string 'heading', default: '', null: false
    t.text 'body', default: '', null: false
    t.integer 'columns', default: 3, null: false
    t.boolean 'show_live_streams', default: false, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[page_id position], name: 'index_page_blocks_on_page_id_and_position'
    t.index ['page_id'], name: 'index_page_blocks_on_page_id'
  end

  create_table 'pages', force: :cascade do |t|
    t.string 'section'
    t.bigint 'parent_id'
    t.string 'title', null: false
    t.string 'slug', null: false
    t.text 'body', default: '', null: false
    t.integer 'position', default: 0, null: false
    t.boolean 'published', default: false, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'system_key'
    t.boolean 'show_title', default: true, null: false
    t.index ['parent_id'], name: 'index_pages_on_parent_id'
    t.index %w[section parent_id position], name: 'index_pages_on_ordering'
    t.index %w[section parent_id slug], name: 'index_pages_on_siblings_slug', unique: true
    t.index %w[section slug], name: 'index_pages_on_top_level_slug', unique: true, where: '(parent_id IS NULL)'
    t.index ['system_key'], name: 'index_pages_on_system_key', unique: true
    t.check_constraint 'section IS NOT NULL OR system_key IS NOT NULL', name: 'pages_belong_somewhere'
  end

  create_table 'site_settings', force: :cascade do |t|
    t.string 'key', null: false
    t.text 'value'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['key'], name: 'index_site_settings_on_key', unique: true
  end

  create_table 'tweets', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.bigint 'twitter_account_id', null: false
    t.text 'body'
    t.datetime 'publish_at'
    t.string 'tweet_id'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['twitter_account_id'], name: 'index_tweets_on_twitter_account_id'
    t.index ['user_id'], name: 'index_tweets_on_user_id'
  end

  create_table 'twitter_accounts', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.string 'name'
    t.string 'username'
    t.string 'image'
    t.string 'token'
    t.string 'secret'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_twitter_accounts_on_user_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'email'
    t.string 'password_digest'
    t.string 'firstname'
    t.string 'lastname'
    t.string 'username'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.boolean 'password_set', default: true, null: false
    t.boolean 'show_stream_on_homepage', default: true, null: false
    t.boolean 'admin', default: false, null: false
    t.datetime 'suspended_at'
    t.string 'suspension_reason'
    t.datetime 'last_sign_in_at'
    t.integer 'sign_in_count', default: 0, null: false
    t.index ['created_at'], name: 'index_users_on_created_at'
    t.index ['suspended_at'], name: 'index_users_on_suspended_at'
  end

  add_foreign_key 'audit_logs', 'users', column: 'actor_id', on_delete: :nullify
  add_foreign_key 'block_items', 'page_blocks', on_delete: :cascade
  add_foreign_key 'block_items', 'pages', column: 'featured_page_id', on_delete: :nullify
  add_foreign_key 'identities', 'users'
  add_foreign_key 'page_blocks', 'pages', on_delete: :cascade
  add_foreign_key 'pages', 'pages', column: 'parent_id'
  add_foreign_key 'tweets', 'twitter_accounts'
  add_foreign_key 'tweets', 'users'
  add_foreign_key 'twitter_accounts', 'users'
end
