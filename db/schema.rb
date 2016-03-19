# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130323211843) do

  create_table "summaries", :force => true do |t|
    t.integer "cik"
    t.string  "irs_number"
    t.integer "subtype"
    t.string  "name"
    t.string  "all_names"
    t.string  "symbol"
    t.string  "cusip"
    t.string  "state_inc"
    t.string  "city"
    t.string  "state"
    t.string  "zip"
    t.text    "owned_by_insider",  :limit => 2147483647
    t.text    "owned_by_5percent", :limit => 2147483647
    t.text    "owner_of_insider",  :limit => 2147483647
    t.text    "owner_of_5percent", :limit => 2147483647
    t.integer "num_filings",                             :default => 0
    t.integer "status",                                  :default => 0
  end

end
