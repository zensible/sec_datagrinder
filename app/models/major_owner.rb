class MajorOwner
  include Mongoid::Document

  field :form_id, type: Integer
  field :form_type, type:  String
  field :form_sec_id, type:  String
  field :date_filed, type: Date
  field :is_group, type: Integer
  field :owner_names, type:  String
  field :issuer_name, type:  String
  field :security_title, type:  String
  field :security_cusip, type:  String
  field :security_shares, type: Integer
  field :percent_of_class, type:  String
  field :subject_name, type:  String
  field :subject_cik, type: Integer
  field :subject_irs_number, type:  String
  field :subject_state_of_incorporation, type:  String
  field :subject_fiscal_year_end, type: Integer
  field :subject_city, type:  String
  field :subject_state, type:  String
  field :subject_zip, type:  String
  field :filer_name, type:  String
  field :filer_cik, type: Integer
  field :filer_irs_number, type: Integer
  field :filer_state_of_incorporation, type:  String
  field :filer_fiscal_year_end, type:  String
  field :filer_city, type:  String
  field :filer_state, type:  String
  field :filer_zip, type:  String
  field :header, type:  String
  field :owners, type:  String
  field :status, type: Integer, default: 0
  field :is_latest, type: Integer, default: 0

  index({ date_filed: -1 }, { unique: false, name: "date_filed_index" })
  index({ subject_cik: 1 }, { unique: false, name: "subject_cik_index" })
  index({ filer_cik: 1 }, { unique: false, name: "filer_cik_index" })
  index({ status: 1 }, { unique: false, name: "status_index" })
  index({ security_title: 1 }, { unique: false, name: "security_title_index" })

end
