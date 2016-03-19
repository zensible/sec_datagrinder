class OsSummaryOrg < ActiveRecord::Base
  attr_accessible :orgname, :dollar_lobby, :dollar_total, :dollar_repub, :dollar_dem, :dollar_indy, :dollar_other, :dollar_cand_repub, :dollar_cand_dem, :dollar_cand_indy, :dollar_cand_other, :dollar_party_repub, :dollar_party_dem, :dollar_party_indy, :dollar_party_other, :dollar_other_business, :dollar_other_labor, :dollar_other_ideological, :dollar_other_other, :donations_cand, :donations_party, :donations_other, :donations_pac_cand, :donations_pac_pac, :dollar_pac_cand_repub, :dollar_pac_cand_dem, :dollar_pac_cand_indy, :dollar_pac_cand_other, :dollar_pac_pac_repub, :dollar_pac_pac_dem, :dollar_pac_pac_indy, :dollar_pac_pac_other, :dollar_pac_other_business, :dollar_pac_other_labor, :dollar_pac_other_ideological, :dollar_pac_other_other, :donations_pac_other, :donations_527, :dollar_527_repub, :dollar_527_dem, :dollar_527_indy, :dollar_527_other, :dollar_527_business, :dollar_527_ideological, :dollar_527_labor, :dollar_527_other

  #searchable do
  #  text :orgname
  #end

end
