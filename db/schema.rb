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

ActiveRecord::Schema.define(:version => 20130623021929) do

  create_table "cik_name_lookup", :primary_key => "row_id", :force => true do |t|
    t.string  "edgar_name"
    t.integer "cik"
    t.string  "match_name"
    t.integer "cw_id"
  end

  add_index "cik_name_lookup", ["cik"], :name => "edgarid"
  add_index "cik_name_lookup", ["cw_id"], :name => "cw_id"
  add_index "cik_name_lookup", ["cw_id"], :name => "cw_id_index"
  add_index "cik_name_lookup", ["match_name"], :name => "match_name"

  create_table "company_names", :primary_key => "name_id", :force => true do |t|
    t.integer "cw_id"
    t.string  "company_name",  :limit => 300
    t.date    "date"
    t.string  "source",        :limit => 30,                     :null => false
    t.integer "source_row_id",                                   :null => false
    t.string  "country_code",  :limit => 2
    t.string  "subdiv_code",   :limit => 3
    t.integer "min_year"
    t.integer "max_year"
    t.boolean "most_recent",                  :default => false, :null => false
  end

  add_index "company_names", ["company_name", "cw_id"], :name => "sort"
  add_index "company_names", ["company_name"], :name => "company_name"
  add_index "company_names", ["country_code", "subdiv_code"], :name => "country_code"
  add_index "company_names", ["cw_id", "company_name", "min_year"], :name => "cw_id"
  add_index "company_names", ["cw_id"], :name => "cw_id_index"
  add_index "company_names", ["min_year", "max_year"], :name => "year"
  add_index "company_names", ["most_recent"], :name => "most_recent"
  add_index "company_names", ["source", "company_name", "cw_id"], :name => "source"

  create_table "company_relations", :primary_key => "relation_id", :force => true do |t|
    t.integer "source_cw_id"
    t.integer "target_cw_id"
    t.string  "relation_type",   :limit => 25
    t.string  "relation_origin", :limit => 25
    t.integer "origin_id"
    t.integer "year"
  end

  add_index "company_relations", ["source_cw_id", "year"], :name => "source"
  add_index "company_relations", ["source_cw_id"], :name => "source_cw_id_index"
  add_index "company_relations", ["target_cw_id", "year"], :name => "targer"
  add_index "company_relations", ["year"], :name => "year"

  create_table "os_527_contribution", :force => true do |t|
    t.integer "CRP_ID"
    t.string  "Rpt",        :limit => 4
    t.string  "FormID",     :limit => 38
    t.string  "SchAID",     :limit => 38
    t.string  "ContribID",  :limit => 12
    t.string  "Contrib",    :limit => 50
    t.float   "Amount"
    t.date    "Date"
    t.string  "Orgname",    :limit => 50
    t.string  "UltOrg",     :limit => 50
    t.string  "RealCode",   :limit => 5
    t.string  "RecipID",    :limit => 9
    t.string  "RecipCode",  :limit => 2
    t.string  "Party",      :limit => 1
    t.string  "Recipient",  :limit => 50
    t.string  "City",       :limit => 50
    t.string  "State",      :limit => 2
    t.string  "Zip",        :limit => 5
    t.string  "Zip4",       :limit => 4
    t.string  "PMSA",       :limit => 4
    t.string  "Employer",   :limit => 70
    t.string  "Occupation", :limit => 70
    t.string  "YTD",        :limit => 17
    t.string  "Gender",     :limit => 1
    t.string  "Source",     :limit => 5
    t.integer "status"
  end

  create_table "os_candidates", :force => true do |t|
    t.integer "Cycle"
    t.string  "FECCandID",    :limit => 9
    t.string  "CID",          :limit => 9
    t.string  "FirstLastP",   :limit => 50
    t.string  "Party",        :limit => 1
    t.string  "DistIDRunFor", :limit => 4
    t.string  "DistIDCurr",   :limit => 4
    t.string  "CurrCand",     :limit => 1
    t.string  "CycleCand",    :limit => 1
    t.string  "CRPICO",       :limit => 1
    t.string  "RecipCode",    :limit => 2
    t.string  "NoPacs",       :limit => 1
  end

  create_table "os_committees", :force => true do |t|
    t.integer "Cycle"
    t.string  "CmteID",      :limit => 9
    t.string  "PACShort",    :limit => 50
    t.string  "Affiliate",   :limit => 50
    t.string  "Ultorg",      :limit => 50
    t.string  "RecipID",     :limit => 9
    t.string  "RecipCode",   :limit => 2
    t.string  "FECCandID",   :limit => 9
    t.string  "Party",       :limit => 1
    t.string  "PrimCode",    :limit => 5
    t.string  "Source",      :limit => 10
    t.string  "IsSensitive", :limit => 1
    t.integer "IsForeign"
    t.integer "Active"
  end

  create_table "os_individual_98", :force => true do |t|
    t.integer "Cycle"
    t.string  "FECTransId", :limit => 19
    t.string  "ContribID",  :limit => 12
    t.string  "Contrib",    :limit => 50
    t.string  "RecipID",    :limit => 9
    t.string  "Orgname",    :limit => 50
    t.string  "UltOrg",     :limit => 50
    t.string  "RealCode",   :limit => 5
    t.date    "DateOf"
    t.integer "Amount"
    t.string  "Street",     :limit => 40
    t.string  "City",       :limit => 30
    t.string  "State",      :limit => 2
    t.string  "Zip",        :limit => 5
    t.string  "RecipCode",  :limit => 2
    t.string  "Type",       :limit => 3
    t.string  "CmteID",     :limit => 9
    t.string  "OtherID",    :limit => 9
    t.string  "Gender",     :limit => 1
    t.string  "Microfilm",  :limit => 11
    t.string  "Occupation", :limit => 50
    t.string  "Employer",   :limit => 50
    t.string  "Source",     :limit => 5
    t.integer "status"
  end

  create_table "os_lobby_industries", :force => true do |t|
    t.string "Client",  :limit => 50
    t.string "Sub",     :limit => 50
    t.float  "Total"
    t.string "Year",    :limit => 4
    t.string "Catcode", :limit => 5
  end

  create_table "os_pac_to_candidates", :force => true do |t|
    t.integer "Cycle"
    t.string  "FECRecNo",  :limit => 19
    t.string  "PACID",     :limit => 9
    t.string  "CID",       :limit => 9
    t.float   "Amount"
    t.date    "Date"
    t.string  "RealCode",  :limit => 5
    t.string  "Type",      :limit => 3
    t.string  "DI",        :limit => 1
    t.string  "FECCandID", :limit => 9
    t.integer "status"
  end

  create_table "os_summary_donors", :force => true do |t|
    t.integer "cycle"
    t.string  "name"
    t.string  "contrib_id"
    t.string  "orgname"
    t.string  "gender"
    t.string  "city"
    t.string  "state"
    t.string  "zip"
    t.string  "occupation"
    t.string  "employer"
    t.integer "dollar_total"
    t.integer "dollar_repub"
    t.integer "dollar_dem"
    t.integer "dollar_indy"
    t.integer "dollar_other"
    t.text    "donations_cand",           :limit => 16777215
    t.integer "dollar_cand_repub"
    t.integer "dollar_cand_dem"
    t.integer "dollar_cand_indy"
    t.integer "dollar_cand_other"
    t.text    "donations_party",          :limit => 16777215
    t.integer "dollar_party_repub"
    t.integer "dollar_party_dem"
    t.integer "dollar_party_indy"
    t.integer "dollar_party_other"
    t.text    "donations_other",          :limit => 16777215
    t.integer "dollar_other_business"
    t.integer "dollar_other_labor"
    t.integer "dollar_other_ideological"
    t.integer "dollar_other_other"
  end

  create_table "os_summary_orgs", :force => true do |t|
    t.string  "orgname"
    t.integer "dollar_lobby"
    t.integer "dollar_total"
    t.integer "dollar_repub"
    t.integer "dollar_dem"
    t.integer "dollar_indy"
    t.integer "dollar_other"
    t.text    "donations_cand",               :limit => 16777215
    t.integer "dollar_cand_repub"
    t.integer "dollar_cand_dem"
    t.integer "dollar_cand_indy"
    t.integer "dollar_cand_other"
    t.text    "donations_party",              :limit => 16777215
    t.integer "dollar_party_repub"
    t.integer "dollar_party_dem"
    t.integer "dollar_party_indy"
    t.integer "dollar_party_other"
    t.text    "donations_other",              :limit => 16777215
    t.integer "dollar_other_business"
    t.integer "dollar_other_labor"
    t.integer "dollar_other_ideological"
    t.integer "dollar_other_other"
    t.text    "donations_pac_cand",           :limit => 16777215
    t.integer "dollar_pac_cand_repub"
    t.integer "dollar_pac_cand_dem"
    t.integer "dollar_pac_cand_indy"
    t.integer "dollar_pac_cand_other"
    t.text    "donations_pac_pac",            :limit => 16777215
    t.integer "dollar_pac_pac_repub"
    t.integer "dollar_pac_pac_dem"
    t.integer "dollar_pac_pac_indy"
    t.integer "dollar_pac_pac_other"
    t.text    "donations_pac_other",          :limit => 16777215
    t.integer "dollar_pac_other_business"
    t.integer "dollar_pac_other_labor"
    t.integer "dollar_pac_other_ideological"
    t.integer "dollar_pac_other_other"
    t.text    "donations_527",                :limit => 16777215
    t.integer "dollar_527_repub"
    t.integer "dollar_527_dem"
    t.integer "dollar_527_indy"
    t.integer "dollar_527_other"
    t.integer "dollar_527_business"
    t.integer "dollar_527_labor"
    t.integer "dollar_527_ideological"
  end

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
    t.text    "subsidiaries",      :limit => 16777215
    t.integer "cw_id"
  end

end
