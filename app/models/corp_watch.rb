class CorpWatch

  def self.cw_to_summary_go

    db_ver = "cw_summ_1f"

    unless $redis.exists(db_ver)
      $redis.set(db_ver, 1)

      sql = "UPDATE summaries SET subsidiaries = ''"
      Db.exec_sql(sql)
    end

    summaries = Summary.find_by_sql("
      SELECT id, cik, subsidiaries, cw_id, name
      FROM summaries
      WHERE subsidiaries = ''
      LIMIT 0, 1000000000
    ")
    summaries.each do |summary|
      #abort summary.inspect
    end

    # For each summary
    summaries.each do |summary|
      puts summary.name
      @hsh_found = {}

      subsidiaries = []

      cw_id = DB::cik_to_cw_id(summary['cik'])
      begin
        hsh_summaries = get_children(cw_id)
      rescue Exception => ex
        abort ex.inspect
      end

      summary.subsidiaries = MultiJson.dump(hsh_summaries)
      summary.cw_id = cw_id
      summary.save
    end

  end

  # Get all cw_ids & ciks of companies who have this company as parent
  def self.get_children(cw_id)
    sql = "
      SELECT DISTINCT (
        CR.target_cw_id
      ) AS cw_id, CWID.cik, CN.company_name as company_name
      FROM company_relations CR
      LEFT OUTER JOIN cik_name_lookup CWID ON CR.target_cw_id = CWID.cw_id
      LEFT OUTER JOIN company_names CN ON CR.target_cw_id = CN.cw_id
      WHERE CR.source_cw_id =  '#{cw_id}'
      ORDER BY CWID.edgar_name
      "

    rows = Db.get_rows(sql)
    arr = []
    rows.each do |row|
      arr << row
    end
    return arr
  end


  def self.get_owner_of(cik)
    @rows_direct = Db.get_rows("select id, issuer_cik, issuer_name, issuer_symbol, security_title, security_shares, period_of_report from direct_owners WHERE owner_cik = #{cik}")
    unless @rows_direct.empty?
      #abort @rows_direct.inspect
    end
    @rows_major = Db.get_rows("select id, subject_cik, subject_name, subject_irs_number, subject_state, subject_city, subject_zip, security_title, security_shares, percent_of_class from major_owners WHERE filer_cik = #{cik}")
    unless @rows_major.empty?
      #abort @rows_major.inspect
    end
    return MultiJson.dump(@rows_direct || []), MultiJson.dump(@rows_major || [])
  end


  def self.cw_to_summary
    ## Progress:
    # SELECT count(cw_id), summary_status FROM `company_names` group by summary_status

    sql = "SELECT count(cw_id) as CNT FROM company_names WHERE summary_status = 0"
    results = ActiveRecord::Base.connection.execute(sql)
    results.each do |res|
      @num_not_processed = res[0]
    end

    sql = "SELECT count(cw_id) as CNT FROM company_names WHERE summary_status = 1"
    results = ActiveRecord::Base.connection.execute(sql)
    results.each do |res|
      @num_processed = res[0]
    end

    sql = "SELECT count(cw_id) as CNT FROM company_names WHERE summary_status = -1"
    results = ActiveRecord::Base.connection.execute(sql)
    results.each do |res|
      @num_processed_no_summ = res[0]
    end

  end

end