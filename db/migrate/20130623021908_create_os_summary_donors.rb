class CreateOsSummaryDonors < ActiveRecord::Migration
  def change
    create_table :os_summary_donors do |t|
      t.integer :cycle
      t.string :name
      t.string :contrib_id
      t.string :orgname
      t.string :gender
      t.string :city
      t.string :state
      t.string :zip
      t.string :occupation
      t.string :employer

      t.integer :dollar_total

      t.integer :dollar_repub
      t.integer :dollar_dem
      t.integer :dollar_indy
      t.integer :dollar_other

      t.text :donations_cand, :limit => 16777215
      t.integer :dollar_cand_repub
      t.integer :dollar_cand_dem
      t.integer :dollar_cand_indy
      t.integer :dollar_cand_other

      t.text :donations_party, :limit => 16777215
      t.integer :dollar_party_repub
      t.integer :dollar_party_dem
      t.integer :dollar_party_indy
      t.integer :dollar_party_other

      t.text :donations_other, :limit => 16777215
      t.integer :dollar_other_business
      t.integer :dollar_other_labor
      t.integer :dollar_other_ideological
      t.integer :dollar_other_other
    end
  end
end
