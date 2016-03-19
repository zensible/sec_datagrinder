class CreateOsSummaryOrgs < ActiveRecord::Migration
  def change
    create_table :os_summary_orgs do |t|
      t.string :orgname

      t.integer :dollar_lobby

      t.integer :dollar_total
      t.integer :dollar_repub
      t.integer :dollar_dem
      t.integer :dollar_indy
      t.integer :dollar_other

      # Individual donations
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

      # PAC donations
      t.text :donations_pac_cand, :limit => 16777215
      t.integer :dollar_pac_cand_repub
      t.integer :dollar_pac_cand_dem
      t.integer :dollar_pac_cand_indy
      t.integer :dollar_pac_cand_other

      t.text :donations_pac_pac, :limit => 16777215
      t.integer :dollar_pac_pac_repub
      t.integer :dollar_pac_pac_dem
      t.integer :dollar_pac_pac_indy
      t.integer :dollar_pac_pac_other

      t.text :donations_pac_other, :limit => 16777215
      t.integer :dollar_pac_other_business
      t.integer :dollar_pac_other_labor
      t.integer :dollar_pac_other_ideological
      t.integer :dollar_pac_other_other

      # 527 donations
      t.text :donations_527, :limit => 16777215
      t.integer :dollar_527_repub
      t.integer :dollar_527_dem
      t.integer :dollar_527_indy
      t.integer :dollar_527_other

      t.integer :dollar_527_business
      t.integer :dollar_527_labor
      t.integer :dollar_527_ideological
      t.integer :dollar_527_other
    end
  end
end
