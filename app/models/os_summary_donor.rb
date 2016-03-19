class OsSummaryDonor < ActiveRecord::Base
  attr_accessible :city, :contrib_id, :cycle, :dollar_dem, :dollar_indy, :dollar_other, :dollar_repub, :dollar_total, :donations, :donations_527, :donations_lobby, :employer, :gender, :name, :occupation, :orgname, :state, :zip

  #searchable do
  #  text :name
  #end

end
