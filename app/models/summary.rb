class Summary < ActiveRecord::Base
  attr_accessible :cik, :city, :cusip, :irs_number, :name, :all_names, :owned_by_5percent, :owned_by_insider, :owner_of_5percent, :owner_of_insider, :state, :state_inc, :status, :symbol, :subtype, :zip, :num_filings, :created_at, :updated_at, :stock_value, :subsidiaries
end
