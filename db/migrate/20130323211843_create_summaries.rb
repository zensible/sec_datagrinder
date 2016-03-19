class CreateSummaries < ActiveRecord::Migration
  def change
    create_table :summaries do |t|
      t.integer :cik
      t.string :irs_number
      t.integer :subtype
      t.string :name
      t.string :all_names
      t.string :symbol
      t.string :cusip
      t.string :state_inc
      t.string :city
      t.string :state
      t.string :zip
      t.text :owned_by_insider, :limit => 4294967295
      t.text :owned_by_5percent, :limit => 4294967295
      t.text :owner_of_insider, :limit => 4294967295
      t.text :owner_of_5percent, :limit => 4294967295
      t.integer :num_filings, :default => 0
      t.integer :status, :default => 0
    end
  end
end
