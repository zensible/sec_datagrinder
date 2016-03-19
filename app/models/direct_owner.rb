class DirectOwner
  include Mongoid::Document

  #validates_presence_of :form_id, :owner_cik, :issuer_cik, :security_shares

  field :form_id, type: Integer
  field :form_sec_id, type:  String
  field :is_direct_owner, type: Boolean
  field :nature_of_ownership, type: String
  field :owner_cik, type: Integer
  field :owner_name, type: String
  field :owner_city, type: String
  field :owner_state, type: String
  field :owner_zip, type: String
  field :owners_all, type: String
  field :is_director, type: Integer
  field :is_officer, type: Integer
  field :is_ten_percent, type: Integer
  field :is_other, type: Integer
  field :other_text, type: String
  field :document_type, type: Integer
  field :period_of_report, type: Date
  field :issuer_cik, type: Integer
  field :issuer_name, type: String
  field :issuer_symbol, type: String
  field :security_title, type: String
  field :security_shares, type: Integer
  field :status, type: Integer, default: 0
  field :is_latest, type: Integer, default: 0

  index({ period_of_report: -1 }, { unique: false, name: "period_of_report_index" })
  index({ owner_cik: 1 }, { unique: false, name: "owner_cik_index" })
  index({ issuer_cik: 1 }, { unique: false, name: "issuer_cik_index" })
  index({ status: 1 }, { unique: false, name: "status_index" })
  index({ security_title: 1 }, { unique: false, name: "security_title_index" })

end