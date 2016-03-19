require 'DB'

class OpenSecrets

  def self.process_recip_code(str)
    arr = str.upcase.split(//)
    char1 = arr[0].upcase
    if arr.length == 1
      char2 = 'u' # unknown
    else
      char2 = arr[1].upcase
    end

    party = status = blio = ''
    if char2 == 'P'
      type = 'party_committee'
      case char1
      when 'D'
        party = 'democratic'
      when 'R'
        party = 'republican'
      when '3'
        party = 'independent / 3rd party'
      else
        party = 'unknown'
      end
    end
    if char1 == 'O'
      type = 'outside_committee' # outside spending committee
      case char2
      when 'B'
        blio = 'business'
      when 'L'
        blio = 'labor'
      when 'I'
        blio = 'ideological'
      when 'O'
        blio = 'other'
      else
        blio = 'unknown'
      end
    end
    if char1 == 'P'
      type = 'other_committee'  # all other committees
      case char2
      when 'B'
        blio = 'business'
      when 'L'
        blio = 'labor'
      when 'I'
        blio = 'ideological'
      when 'O'
        blio = 'other'
      else
        blio = 'unknown'
      end
    end
    if type.blank?
      type = 'candidate'
      case char1
      when 'D'
        party = 'democratic'
      when 'R'
        party = 'republican'
      when '3'
        party = 'independent / 3rd party'
      else
        party = 'unknown'
      end
      case char2
      when 'W'
        status = 'winner'
      when 'L'
        status = 'loser'
      when 'I'
        status = 'incumbent'
      when 'C'
        status = 'challenger'
      when 'O'
        status = 'open seat'
      when 'N'
        status = 'non-incumbent'
      end
    end

    return [type, blio, party, status]
  end

  def self.get_committee_by_id(committees, id_to_find)
    committee = committee_fallback = nil
    committees.each do |row_recip| # Find the latest record, since they get one entry per year, and filter out if it doesn't have RecipCode
      if row_recip['CmteID'] == id_to_find
        committee_fallback = row_recip
        if row_recip['RecipCode'].blank? # Keep checking 
          next
        else # Has necessary info
          committee = row_recip
          break
        end
      end
    end
    if committee.nil?
      if committee_fallback.nil?
        abort("==== Could not find committee: #{id_to_find}")
      else
        committee = committee_fallback
      end
    end

    committee
  end

  def self.get_candidate_by_id(candidates, id_to_find)
    candidates.each do |cand|
      if cand['CID'] == id_to_find
        return cand['FirstLastP']
      end
    end
    abort "Could not find candidate: #{id_to_find}"
  end

  def year2to4(year)
    if year.to_i >= 80
      return "19#{year}"
    else
      return "20#{year}"
    end
  end

  def self.create_and_populate_tables(mode, all_cycles)
    tables_campaign = {
      "os_candidates" => {
        "Cycle" => "int",
        "FECCandID" => 9,
        "CID" => 9,
        "FirstLastP" => 50,
        "Party" => 1,
        "DistIDRunFor" => 4,
        "DistIDCurr" => 4,
        "CurrCand" => 1,
        "CycleCand" => 1,
        "CRPICO" => 1,
        "RecipCode" => 2,
        "NoPacs" => 1
      },
      "os_committees" => {
        "Cycle" => "int",
        "CmteID" => 9,
        "PACShort" => 50,
        "Affiliate" => 50,
        "Ultorg" => 50,
        "RecipID" => 9,
        "RecipCode" => 2,
        "FECCandID" => 9,
        "Party" => 1,
        "PrimCode" => 5,
        "Source" => 10,
        "IsSensitive" => 1, # Renamed because 'Sensitive' is a reserved word
        "IsForeign" => "int", # Renamed because 'Foreign' is a reserved word
        "Active" => "int"
      },
      "os_pac_to_candidates" => {
        "Cycle" => "int",
        "FECRecNo" => 19,
        "PACID" => 9,
        "CID" => 9,
        "Amount" => "float",
        "Date" => "date",
        "RealCode" => 5,
        "Type" => 3,
        "DI" => 1,
        "FECCandID" => 9,
        "status" => "int"
      },
      "os_pac_to_pac" => {
        "Cycle" => "int",
        "FECRecNo" => 19,
        "Filerid" => 9,
        "DonorCmte" => 50,
        "ContribLendTrans" => 50,
        "City" => 50,
        "State" => 2,
        "Zip" => 5,
        "FECOccEmp" => 38,
        "Primcode" => 5,
        "DateOf" => "date", # Renamed from Date
        "Amount" => "float",
        "RecipID" => 9,
        "Party" => 1,
        "Otherid" => 9,
        "RecipCode" => 2,
        "RecipPrimCode" => 5,
        "Amend" => 1,
        "Report" => 3,
        "PG" => 1,
        "Microfilm" => 11,
        "Type" => 3,
        "RealCode" => 5,
        "Source" => 5,
        "status" => "int"
      },
      "os_individual" => {
        "Cycle" => "int",
        "FECTransId" => 19,
        "ContribID" => 12,
        "Contrib" => 50,
        "RecipID" => 9,
        "Orgname" => 50,
        "UltOrg" => 50,
        "RealCode" => 5,
        "DateOf" => "date",
        "Amount" => "int",
        "Street" => 40,
        "City" => 30,
        "State" => 2,
        "Zip" => 5,
        "RecipCode" => 2,
        "Type" => 3,
        "CmteID" => 9,
        "OtherID" => 9,
        "Gender" => 1,
        "Microfilm" => 11,
        "Occupation" => 50,
        "Employer" => 50,
        "Source" => 5,
        "status" => "int"
      },
    }

    tables_lobby = {
      "os_lobby_agency" => {
        "Uniqid" => 36,
        "AgencyID" => 3,
        "Agency" => 80
      },
      "os_lobby_bills" => {
        "B_ID" => "int",
        "SI_ID" => "int",
        "CongNo" => 3,
        "Bill_Name" => 15
      },
      "os_lobby_industries" => {
        "Client" => 50,
        "Sub" => 50,
        "Total" => "float",
        "Year" => 4,
        "Catcode" => 5
      },
      "os_lobby_issues" => {
        "S_ID" => "int",
        "Uniqid" => 36,
        "IssueID" => 3,
        "Issue" => 50,
        "SpecificIssue" => 512,
        "Year" => 4
      },
      "os_lobby_issues_nonspecific" => {
        "S_ID" => "int",
        "Uniqid" => 36,
        "IssueID" => 3,
        "Issue" => 50,
        "Year" => 4
      },
      "os_lobby_lobbying" => {
        "Uniqid" => 36,
        "Registrant_raw" => 110,
        "Registrant" => 50,
        "Isfirm" => 1,
        "Client_raw" => 110,
        "Client" => 50,
        "Ultorg" => 50,
        "Amount" => "float",
        "Catcode" => 5,
        "Source" => 5,
        "Self" => 1,
        "IncludeNSFS" => 1,
        "UseCode" => 1,
        "Ind" => 1,
        "Year" => 4,
        "Type" => 4,
        "Typelong" => 80,
        "Affiliate" => 1,
        "status" => "int"
      },
      "os_lobby_lobbyists" => {
        "UniqID" => 36,
        "Lobbyist_raw" => 50,
        "Lobbyist" => 50,
        "Lobbyist_id" => 12,
        "Year" => 4,
        "OfficialPosition" => 100,
        "CID" => 15,
        "Formercongmem" => 1,
      },
      "os_lobby_report_types" => {
        "type" => 50,
        "code" => 4,
      },
    }

    tables_527 = {
      "os_527_committies" => {
        "Cycle" => 4,
        "Rpt" => 4,
        "EIN" => 9,
        "CRP527Name" => 40,
        "Affiliate" => 40,
        "UltOrg" => 40,
        "RecipCode" => 2,
        "CmteID" => 9,
        "CID" => 9,
        "ECCmteID" => 10,
        "Party" => 1,
        "PrimCode" => 5,
        "Source" => 10,
        "FFreq" => 1,
        "Ctype" => 10,
        "CSource" => 5,
        "ViewPt" => 1,
        "Comments" => 250,
        "State" => 2
      },
      "os_527_contribution" => {
        "CRP_ID" => "int",
        "Rpt" => 4,
        "FormID" => 38,
        "SchAID" => 38,
        "ContribID" => 12,
        "Contrib" => 50,
        "Amount" => "float",
        "Date" => "date",
        "Orgname" => 50,
        "UltOrg" => 50,
        "RealCode" => 5,
        "RecipID" => 9,
        "RecipCode" => 2,
        "Party" => 1,
        "Recipient" => 50,
        "City" => 50,
        "State" => 2,
        "Zip" => 5,
        "Zip4" => 4,
        "PMSA" => 4,
        "Employer" => 70,
        "Occupation" => 70,
        "YTD" => 17,
        "Gender" => 1,
        "Source" => 5,
        "status" => "int"
      },
      "os_527_expenditure" => {
        "Rpt" => 4,
        "FormID" => 38,
        "SchBID" => 38,
        "Orgname" => 70,
        "EIN" => 9,
        "Recipient" => 50,
        "RecipientCRP" => 50,
        "Amount" => "int",
        "Date" => "date",
        "ExpCode" => 3,
        "Source" => 5,
        "Purpose" => 512,
        "Addr1" => 50,
        "Addr2" => 50,
        "City" => 50,
        "State" => 2,
        "Zip" => 5,
        "Employer" => 70,
        "Occupation" => 70
      },
    }

    tables_expenditure = {
      "os_finances_agreements" => {
        "Rpt" => 4,
        "FormID" => 38
        },
    }

    files_campaign = {
      "os_candidates" => "cands",
      "os_committees" => "cmtes",
      "os_pac_to_candidates" => "pacs",
      "os_pac_to_pac" => "pac_other",
      "os_individual" => "indivs"
    }

#      "os_lobby_agency" => "lob_agency",
#      "os_lobby_bills" => "lob_bills",
#      "os_lobby_issues" => "lob_issue",
    #  "os_lobby_report_types" => "lob_rpt",
    #  "os_lobby_issues_nonspecific" => "lob_issue_NoSpecficIssue",
    #  "os_lobby_lobbying" => "lob_lobbying",
    #  "os_lobby_lobbyists" => "lob_lobbyist",

    # We only use lobby_industries for the summaries
    files_lobby = {
      "os_lobby_industries" => "lob_indus"
    }

    #  "os_527_committees" => "cmtes527",
    #  "os_527_expenditure" => "expends527",
    files_527 = {
      "os_527_contribution" => "rcpts527"
    }

    case mode
    when "campaign"
      tables = tables_campaign
      files = files_campaign
    when "lobby"
      tables = tables_lobby
      files = files_lobby
    when "527"
      tables = tables_527
      files = files_527
    end

    # Drop and create tables
    tables_fields = {}
    tables.each do |tbl, fields|
      next unless files[tbl]

      tables_fields[tbl] = []

      sql = "DROP TABLE IF EXISTS #{tbl}"
      puts sql
      #Db.exec_sql(sql)

      sql = "CREATE TABLE IF NOT EXISTS #{tbl} (id INT NOT NULL AUTO_INCREMENT, "
      fields.each_with_index do |fld, i|
        typ = fld[1]
        fld = fld[0]

        tables_fields[tbl] << fld

        sql += "#{fld} "
        if typ.is_a?(Fixnum) # Number
          sql += " VARCHAR(#{typ})"
        else
          sql += typ
        end
        if i == fields.size - 1
          sql += ", PRIMARY KEY (id))"
        else
          sql += ", "
        end
      end

      if mode == "campaign" && tbl == "os_individual"
        # Create tables, sharded by year
        all_cycles.each do |year|
          puts sql
          Db.exec_sql(sql.gsub("os_individual", "os_individual_" + year))
        end
      else
        puts sql
        Db.exec_sql(sql)
      end

    end

    str = ""

    case mode
    when "campaign"
      years = all_cycles
    else
      years = [ true ]
    end

    ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')

    files.each do |tbl, filename|
      cnt = 0
      years.each do |year|
        puts "== Year: #{year}"
        arr_fields = tables_fields[tbl]

        case mode
        when "campaign"
          fullpath = "data/opensecrets/#{mode}/#{filename}#{year}.txt"
        else
          fullpath = "data/opensecrets/#{mode}/#{filename}.txt"
        end
        puts "==== Processing file: #{fullpath}"
        #skip_all = true
        file = File.open("#{fullpath}")
        while cur_line = file.gets

          cur_line_before = cur_line

          cur_line = ic.iconv(cur_line)
          cur_line = cur_line.gsub(/"/, "`")
          cur_line = cur_line.gsub(/'/, "`")
          while cur_line.match(/,,/)
            cur_line = cur_line.gsub(/,,/, ',||,')
          end
          cur_line = cur_line.gsub(/\|,(\d\d)\/(\d\d)\/(\d\d\d\d),(-?)(\d+),\|/, "|,|\\1/\\2/\\3|,|\\4\\5|,|")
          cur_line = cur_line.gsub(/^\|/, '"')
          cur_line = cur_line.gsub(/\|\s+$/, '"')
          cur_line = cur_line.gsub(/\|,\|/, '","')
          cur_line = cur_line.gsub(/\|,/, '",')
          cur_line = cur_line.gsub(/,\|/, ',"')
          #cur_line = cur_line.gsub(/(\d)/, "\\1")

          cnt += 1
          if cnt % 10000 == 0
            puts "== line: #{cnt}"
          end

          begin
            # There are occasional errors in CSV, ignore the whole line but log the error
            values = CSV.parse(cur_line)
          rescue => ex
            puts "Error at line: #{cnt}: #{ex.inspect} -- #{values.inspect}"
            next
          end
          values = values[0]

          # ==== If you need to restart the process due to memory going away
          #fec_trans_id = values[1] || ""
          #if fec_trans_id.to_i < 1881212
          #  next
          #end

          rec = {}

          tbl_cur = tbl
          tbl_cur += "_" + year if mode == "campaign" && filename == "indivs"

          sql = "INSERT INTO #{tbl_cur} ("
          sql_fld = sql_val = ""
          (0..values.length - 1).each do |i|
            key = arr_fields[i]
            val = values[i]
            if val.nil?
              val = ""
            else
              #val = ic.iconv(val + ' ')[0..-2]
              val = val.gsub(/'/, '`')
              val = val.gsub(/\\+$/, "")
              val = val.gsub(/^\s+/, "")
              val = val.gsub(/\s+$/, "")

              # MM/DD/YYYY -> YYYY-MM-DD
              if val.match(/^\d\d\/\d\d\/\d\d\d\d$/)
                arr = val.split(/\//)
                val = arr[2] + '-' + arr[0] + '-' + arr[1]
              end
            end

            # Occasionally the date is missing in the OpenSecrets data. Defaults to 1/1/#{year} so the data can still make it to the summary.
            if val == ''
              field_type = tables[tbl][key]
              if field_type == 'date'
                if mode == 'campaign'
                  val = "#{year2to4(year)}-1-1"
                elsif mode == '527'
                  rpt = values[1]  # Rpt field
                  yr = rpt.slice(2, 2)
                  qtr = rpt.slice(1, 1).to_i
                  month = (qtr * 3) - 2
                  val = "#{year2to4(yr)}-#{month}-1"
                end
                puts "Default DATE: #{val}"
              end
            end

            sql_fld += "#{key}"
            if i != values.length - 1
              sql_fld += ", "
            end

            sql_val += "'#{val}'"
            if i != values.length - 1
              sql_val += ", "
            end

          end

          sql = "#{sql} #{sql_fld}) VALUES (#{sql_val})"
#abort sql
          begin
            Db.exec_sql(sql)
          rescue => ex
            puts "
Error inserting record: #{cnt}: #{ex.inspect} -- #{values.inspect}

Before:

#{cur_line_before}

After:
#{cur_line}
"
          end
        end
      end # year
    end

  end

  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  # ====== STEP 1: Create os_summary_donor records
  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  def self.prepare_os_summary_donor(all_cycles)
    # This should take about 2 hours

    start = Time.now

    Db::log_time(start, "To see progress: SELECT count(id) FROM `os_summary_donors`")
    Db::log_time(start, "== INDEXES: CREATE UNIQUE INDEX contribid_index ON os_summary_donors (ContribID)")
    Db::log_time(start, "== STOP SOLR: bundle exec rake sunspot:solr:stop RAILS_ENV=development  AND  comment it out in os_summary_donors")
    Db::log_time(start, "start")

    # Total distinct donors: SELECT count(distinct(contribId)) FROM `os_individual_00` WHERE 1

    # Create empty OsSummaryDonor records, one for each ContribId, a unique identifier for each individual contributor
    # First create records of all the 2016 donors, then 2014 etc
    all_cycles.each do |year|
      Db::log_time(start, "year #{year}")
      num_batch = 100000
      page = 0
      cnt = 0
      keep_going = true
      while keep_going
        sql = "
          SELECT id, ContribID as contrib_id, Contrib as name, Orgname as orgname, street, city, state, zip, gender, employer, source
          FROM os_individual_#{year}
          WHERE ContribID != '' AND ContribID NOT IN (SELECT contrib_id FROM os_summary_donors)
          GROUP BY ContribID
          LIMIT 0, #{num_batch}
        "
        # LIMIT #{page * num_batch}, #{num_batch}
        Db::log_time(start, "=== prepare start: \n#{sql}")

        rows = Db.get_rows(sql)
        keep_going = rows.length > 1

        Rails.logger.warn Time.new.inspect + " == prepare GO"
        rows.each do |indiv|
          if cnt % 10000 == 0
            Db::log_time(start, "=== prepare row #{cnt}")
          end
          cnt += 1
          sql = "
            INSERT INTO os_summary_donors
            (cycle, contrib_id, name, orgname, city, state, zip, employer, occupation, gender)
            VALUES
            (
              '#{year2to4(year)}',
              '#{indiv['contrib_id']}',
              '#{indiv['name']}',
              '#{indiv['orgname']}',
              '#{indiv['city']}',
              '#{indiv['state']}',
              '#{indiv['zip']}',
              '#{indiv['employer']}',
              '#{indiv['occupation']}',
              '#{indiv['gender']}'
            )
          "
          Db.exec_sql(sql)
        end

        page += 1
      end

    end

    Db::log_time(start, "done")
  end

  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  # ====== STEP 2: Populate os_summary_donor records with data
  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  def self.populate_os_summary_donor(all_cycles)
    # This took about 30 hours to run for me. You can start/stop it as necessary, it will restart.

    start = Time.now

    Db::log_time(start, "Process_opensecrets")

    # ALTER TABLE  `os_summary_donors` ADD UNIQUE ( `contrib_id` )

    sql = "
      SELECT CmteID, PACShort, Ultorg, RecipCode, PrimCode
      FROM os_committees
      GROUP BY CmteID
      ORDER BY cycle DESC
      "
    Db::log_time(start, "COMMITTEES: #{sql}")
    rows = Db.get_rows(sql)
    committees = {}
    rows.each do |cmte|
      committees[cmte['CmteID']] = cmte
    end


    # Load recipient committees into memory (pacs)
    #sql = "
    #  SELECT CmteID, PACShort, Ultorg, RecipCode, PrimCode
    #  FROM os_committees
    #  ORDER BY cycle DESC
    #  "
    #committees = Db.get_rows(sql)

    sql = "
      SELECT CID, FirstLastP
      FROM os_candidates
      ORDER BY cycle DESC
      "
    Db::log_time(start, "CANDIDATES: #{sql}")
    candidates = Db.get_rows(sql)

    # Read summary ids/contrib_ids in batches
    num_batch = 1000
    page = 0
    cnt = 0
    keep_going = true

    Db::log_time(start, "Starting")

    while keep_going
      sql = "
        SELECT id, contrib_id
        FROM os_summary_donors
        WHERE dollar_total = -1
        LIMIT 0, #{num_batch}
      " # #   {num_batch * page} 
      donors = Db.get_rows(sql)
      Db::log_time(start, "donors: #{donors}")

      page += 1

      keep_going = donors.length > 1

      Db::log_time(start, "Start batch: #{page * num_batch}\n#{donors[0].inspect}")

      abort "Done!" unless keep_going


      # For each unique donor
      donors.each do |donor|
        donor_summary_id = donor['id']
        contrib_id = donor['contrib_id']

        # contrib_id = "a0000368662A"  Has lots of donations

        donations_cand = []
        dollar_cand_repub = 0
        dollar_cand_dem = 0
        dollar_cand_indy = 0
        dollar_cand_other = 0

        donations_party = []
        dollar_party_repub = 0
        dollar_party_dem = 0
        dollar_party_indy = 0
        dollar_party_other = 0

        donations_other = []
        dollar_other_business = 0
        dollar_other_labor = 0
        dollar_other_ideological = 0
        dollar_other_other = 0

        all_cycles.each do |year|  # For each year of info we ave

          # Retrieve all donations by that contributor for that year, group by recipients and get the SUM of the amounts to that recip
          #   ToDo: this dedupes, should see if it's necessary: group by committee_id + "_" + cast(date as char) + "_" + cast(amount as char)  -- ToDo: should we omit dupes this way?
          sql = "
            SELECT id, ContribID as contrib_id, CmteID as committee_id, RecipID as recip_id, Contrib as name, Orgname as orgname, DateOf as date, SUM(amount) as amount, RecipCode as recip_code, type, source
            FROM os_individual_#{year}
            WHERE ContribID = '#{contrib_id}'
              AND RecipCode != ''
            GROUP BY committee_id
          " # Group By essentially groups all donations by year
          donations = Db.get_rows(sql)
          if donations.length == 0
            #Db::log_time(start, "No donors found")
            next
          end

          # For each individual contribution record...
          donations.each_with_index do |donation, i|

            if cnt % 1000 == 0
              Db::log_time(start, "prepare row #{cnt}")
              Db::log_time(start, "Donor: #{donor_summary_id} #{contrib_id}")
            end
            cnt += 1

            # Figure out who the recipient is and their political affiliation
            recip = {}

            amt = donation['amount'].to_i

            (type, blio, party, status) = OpenSecrets.process_recip_code(donation['recip_code'])

            #if type == 'candidate'
            #  recip_name = OpenSecrets.get_candidate_by_id(candidates, donation['recip_id'])
            #else
            committee = committees[donation['committee_id']]
            if committee.blank?
              puts "== Couldn't find committee #{donation['committee_id']}"
              next
            end
            recip_name = committee['PACShort']
            #end

            # Save the donation record + recipient committee to the JSON
            donation_abbrev = {
              :amount => donation['amount'],
              :date => donation['date'],
              :recip_name => recip_name,
              :committee_id => donation['committee_id'],
              :recip_id => donation['recip_id'],
              :type => type,
              :blio => blio,
              :party => party,
              :status => status
            }

            case type
            when /candidate/
              donations_cand << donation_abbrev
              case party
              when "republican"
                dollar_cand_repub += amt
              when "democratic"
                dollar_cand_dem += amt
              when "independent / 3rd party"
                dollar_cand_indy += amt
              else
                dollar_cand_other += amt
              end
            when /party_committee/
              donations_party << donation_abbrev
              case party
              when "republican"
                dollar_party_repub += amt
              when "democratic"
                dollar_party_dem += amt
              when "independent / 3rd party"
                dollar_party_indy += amt
              else
                dollar_party_other += amt
              end
            when /outside_committee|other_committee/
              donations_other << donation_abbrev
              case blio
              when "business"
                dollar_other_business += amt
              when "labor"
                dollar_other_labor += amt
              when "ideological"
                dollar_other_ideological += amt
              else
                dollar_other_other += amt
              end
            end
          end
        end # /year

        dollar_repub = dollar_cand_repub + dollar_party_repub
        dollar_dem = dollar_cand_dem + dollar_party_dem
        dollar_indy = dollar_cand_indy + dollar_party_indy
        dollar_other = dollar_cand_other + dollar_party_other
        dollar_total = dollar_repub + dollar_dem + dollar_indy + dollar_other

        num_to_store = 40

        # Sort largest to smallest
        donations_cand = donations_cand.sort { |a,b| b[:amount].to_i <=> a[:amount].to_i }.slice(0, num_to_store)
        donations_party = donations_party.sort { |a,b| b[:amount].to_i <=> a[:amount].to_i }.slice(0, num_to_store)
        donations_other = donations_other.sort { |a,b| b[:amount].to_i <=> a[:amount].to_i }.slice(0, num_to_store)

        sql = "
          UPDATE os_summary_donors
          SET
            donations_cand = '#{MultiJson.dump(donations_cand)}',
            donations_party = '#{MultiJson.dump(donations_party)}',
            donations_other = '#{MultiJson.dump(donations_other)}',

            dollar_total = '#{dollar_total}',

            dollar_repub = '#{dollar_repub}',
            dollar_dem = '#{dollar_dem}',
            dollar_indy = '#{dollar_indy}',
            dollar_other = '#{dollar_other}',

            dollar_cand_repub = '#{dollar_cand_repub}',
            dollar_cand_dem = '#{dollar_cand_dem}',
            dollar_cand_indy = '#{dollar_cand_indy}',
            dollar_cand_other = '#{dollar_cand_other}',
            dollar_party_repub = '#{dollar_party_repub}',
            dollar_party_dem = '#{dollar_party_dem}',
            dollar_party_indy = '#{dollar_party_indy}',
            dollar_party_other = '#{dollar_party_other}',
            dollar_other_business = '#{dollar_other_business}',
            dollar_other_labor = '#{dollar_other_labor}',
            dollar_other_ideological = '#{dollar_other_ideological}',
            dollar_other_other = '#{dollar_other_other}'
          WHERE id = '#{donor_summary_id}'
        "
        Db.exec_sql(sql)
        Db::log_time(start, "Update: #{donor_summary_id}")
      end # /donor
    end # / keep_going
  end


  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  # ====== STEP 3: Create and populate os_summary_org records
  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  def self.populate_os_summary_org(org = "")
    # This should take about X hours

    start = Time.now

    Db::log_time(start, "starting. Progress: rails c & OsSummaryOrg.count")

    # ==== Load all committees and candidates into memory, indexed by their primary key id
    sql = "
      SELECT CmteID, PACShort, Ultorg, RecipCode, PrimCode
      FROM os_committees
      GROUP BY CmteID
      ORDER BY cycle DESC
      "
    rows = Db.get_rows(sql)
    committees = {}
    rows.each do |cmte|
      committees[cmte['CmteID']] = cmte
    end

    sql = "
      SELECT CID, FirstLastP as name, Cycle as cand_cycle, party
      FROM os_candidates
      GROUP BY CID
      ORDER BY cycle DESC
      "
    rows = Db.get_rows(sql)
    candidates = {}
    rows.each do |cmte|
      candidates[cmte['CID']] = cmte
    end

    num_to_store = 40

    keep_going = true

    while keep_going

      # ==== Load all distinct orgnames (since that's what we'll be searching on)
      if org.blank?
        where = "orgname NOT IN ('', 'Retired', 'Homemaker', 'Actor') AND orgname NOT IN (SELECT orgname FROM os_summary_orgs)"
      else
        where = "orgname = '#{org}'"
        orgs = OsSummaryOrg.where("orgname = '#{org}'")
      end
      sql = "
        SELECT distinct(orgname)
        FROM os_summary_donors
        WHERE #{where}
        LIMIT 0, 5000
        "
      Db::log_time(start, "Get 5000 orgs START")
      rows = Db.get_rows(sql)
      keep_going = rows.length > 0 
      Db::log_time(start, "Get 5000 orgs END")

      cnt = 0
      # ==== For each organization we have records for...
      rows.each do |row|
        orgname = row['orgname']
        next if orgname.blank?

        cnt += 1
        if cnt % 1000 == 0
          Rails.logger.warn("=== created org # #{cnt}")
        end

        #==== Figure out aggregate amount of money lobbied
        sql = "
          SELECT sum(total) AS dollar_lobby
          FROM `os_lobby_industries`
          WHERE `Sub` = '#{orgname}'
          "
        dollar_lobby = Db.get_field(sql)
        dollar_lobby = 0 if dollar_lobby.blank?

        #==== Load the current committee's CmteID
        sql = "
          SELECT distinct(CmteID) as CmteID
          FROM os_committees
          WHERE Ultorg = '#{orgname}'
        "
        pac_cmte_id = Db.get_field(sql)
        #puts "== Not found: #{sql}" if pac_cmte_id.blank?

        totals = {}
        if !pac_cmte_id
          donations_pac_cand = []
          donations_pac_pac = []
          donations_pac_other = []

          totals = {
            "dollar_pac_cand_repub" => 0,
            "dollar_pac_cand_dem" => 0,
            "dollar_pac_cand_indy" => 0,
            "dollar_pac_cand_other" => 0,
            "dollar_pac_pac_repub" => 0,
            "dollar_pac_pac_dem" => 0,
            "dollar_pac_pac_indy" => 0,
            "dollar_pac_pac_other" => 0,
            "dollar_pac_other_business" => 0,
            "dollar_pac_other_labor" => 0,
            "dollar_pac_other_ideological" => 0,
            "dollar_pac_other_other" => 0
          }
        else
          # ==== Step 1: process os_pac_to_candidates into donations array and totals
          donations_pac_cand = []
          dollar_pac_cand_repub = 0
          dollar_pac_cand_dem = 0
          dollar_pac_cand_indy = 0
          dollar_pac_cand_other = 0

          sql = "
            SELECT PC.CID AS cand_id, Amount AS amount, PC.Date AS date
            FROM os_pac_to_candidates PC
            WHERE PACID = '#{pac_cmte_id}'
          "
          donations = Db.get_rows(sql)

          #==== Get totals from donations, population donations_pac_cand
          donations.each do |donation|

            candidate = candidates[donation['cand_id']] || {}
            donation['name'] = candidate['name'] || ""
            donation['cand_cycle'] = candidate['cand_cycle'] || "-1"
            donation['party'] = candidate['party'] || ""

            amt = donation['amount']

            # Save the donation record + recipient committee to the JSON
            donation_abbrev = {
              :amount => amt,
              :date => donation['date'],
              :recip_name => donation['name'],
              :recip_id => donation['cand_id'],
              :party => donation['party']
            }

            donations_pac_cand << donation_abbrev

            case donation['party']
            when "R"
              dollar_pac_cand_repub += amt
            when "D"
              dollar_pac_cand_dem += amt
            when "3"
              dollar_pac_cand_indy += amt
            else
              dollar_pac_cand_other += amt
            end
          end
          donations_pac_cand = donations_pac_cand.sort { |a,b| b[:amount].to_i <=> a[:amount].to_i }.slice(0, num_to_store)

          totals = {
            "dollar_pac_cand_repub" => dollar_pac_cand_repub,
            "dollar_pac_cand_dem" => dollar_pac_cand_dem,
            "dollar_pac_cand_indy" => dollar_pac_cand_indy,
            "dollar_pac_cand_other" => dollar_pac_cand_other
          }

          donations_pac_pac = []

          # ==== Step 2: process os_pac_to_pac into donations array and totals
          # Note: 1*: ??, 2*: direct contribution
          donations_pac_pac = []
          dollar_pac_pac_repub = 0
          dollar_pac_pac_dem = 0
          dollar_pac_pac_indy = 0
          dollar_pac_pac_other = 0

          donations_pac_other = []
          dollar_pac_other_business = 0
          dollar_pac_other_labor = 0
          dollar_pac_other_ideological = 0
          dollar_pac_other_other = 0

          sql = "
            SELECT DateOf AS date, Amount AS amount, RecipID as recip_id, RecipCode as recip_code, Otherid as committee_id
            FROM os_pac_to_pac
            WHERE Otherid = '#{pac_cmte_id}' AND Type LIKE '1%' AND RecipCode != ''
            UNION
            SELECT DateOf AS date, Amount AS amount, RecipID as recip_id, RecipCode as recip_code, Otherid as committee_id
            FROM os_pac_to_pac
            WHERE Filerid = '#{pac_cmte_id}' AND Type LIKE '2%' AND RecipCode != ''
          "
          donations = Db.get_rows(sql)

          #==== Get totals from donations, TABLE: donations_pac_pac
          donations.each do |donation|
            amt = donation['amount']

            next if donation['committee_id'].blank?

            committee = committees[donation['committee_id']]
            if committee.blank?
              puts " +=+=+=+ +=+=+=+ +=+=+=+ Could't find committee #{donation['committee_id']}"
              next
            end
            donation['name'] = committee['PACShort']

            # Save the donation record + recipient committee to the JSON
            (type, blio, party, status) = OpenSecrets.process_recip_code(donation['recip_code'])

            # Save the donation record + recipient committee to the JSON
            donation_abbrev = {
              :amount => amt,
              :date => donation['date'],
              :recip_name => donation['name'],
              :recip_id => donation['recip_id'],
              :type => type,
              :blio => blio,
              :party => party,
              :status => status
            }

            # ==== Get totals from donations, TABLE: donations_pac_pac
            case type
            when /party_committee/
              donations_pac_pac << donation_abbrev
              case party
              when "republican"
                dollar_pac_pac_repub += amt
              when "democratic"
                dollar_pac_pac_dem += amt
              when "independent / 3rd party"
                dollar_pac_pac_indy += amt
              else
                dollar_pac_pac_other += amt
              end
            when /outside_committee|other_committee/
              donations_pac_other << donation_abbrev
              case blio
              when "business"
                dollar_pac_other_business += amt
              when "labor"
                dollar_pac_other_labor += amt
              when "ideological"
                dollar_pac_other_ideological += amt
              else
                dollar_pac_other_other += amt
              end
            end
          end
          donations_pac_pac = donations_pac_pac.sort { |a,b| b[:amount].to_i <=> a[:amount].to_i }.slice(0, num_to_store)

          totals = totals.merge({
            "dollar_pac_pac_repub" => dollar_pac_pac_repub,
            "dollar_pac_pac_dem" => dollar_pac_pac_dem,
            "dollar_pac_pac_indy" => dollar_pac_pac_indy,
            "dollar_pac_pac_other" => dollar_pac_pac_other,
            "dollar_pac_other_business" => dollar_pac_other_business,
            "dollar_pac_other_labor" => dollar_pac_other_labor,
            "dollar_pac_other_ideological" => dollar_pac_other_ideological,
            "dollar_pac_other_other" => dollar_pac_other_other
          })
        end # end pac_id found

        # ==== Step 4: Take care of individual donors to cands / party / other
        dollar_total = 0
        dollar_repub = 0
        dollar_dem = 0
        dollar_indy = 0
        dollar_other = 0

        ## Get all dollar totals
        #Db::log_time(start, "get SUMS")
        sql = "
          SELECT
            SUM(dollar_cand_repub) AS dollar_cand_repub,
            SUM(dollar_cand_dem) AS dollar_cand_dem,
            SUM(dollar_cand_indy) AS dollar_cand_indy,
            SUM(dollar_cand_other) AS dollar_cand_other,
            SUM(dollar_party_repub) AS dollar_party_repub,
            SUM(dollar_party_dem) AS dollar_party_dem,
            SUM(dollar_party_indy) AS dollar_party_indy,
            SUM(dollar_party_other) AS dollar_party_other,
            SUM(dollar_other_business) AS dollar_other_business,
            SUM(dollar_other_labor) AS dollar_other_labor,
            SUM(dollar_other_ideological) AS dollar_other_ideological,
            SUM(dollar_other_other) AS dollar_other_other
          FROM os_summary_donors
          WHERE orgname = '#{orgname}'
        "
        sums = Db.get_row(sql)
        if sums['dollar_cand_repub'].nil?
          puts "=== blank sums: " + sums.inspect
          sums = {
            "dollar_cand_repub" => 0,
            "dollar_cand_dem" => 0,
            "dollar_cand_indy" => 0,
            "dollar_cand_other" => 0,
            "dollar_party_repub" => 0,
            "dollar_party_dem" => 0,
            "dollar_party_indy" => 0,
            "dollar_party_other" => 0,
            "dollar_other_business" => 0,
            "dollar_other_labor" => 0,
            "dollar_other_ideological" => 0,
            "dollar_other_other" => 0
          }
        end
        totals = totals.merge(sums)
        #Db::log_time(start, "Get Sums END")

        ## Get top X donors from each category
        #Db::log_time(start, "Get Donors START")
        sql = "
          SELECT donations_cand, donations_party, donations_other
          FROM os_summary_donors
          WHERE orgname = '#{orgname}'
        "
        donors = Db.get_rows(sql)
        #Db::log_time(start, "Get Donors END")

        ## Get the 'top of the top' donors for this organization
        donations_cand = []
        donations_party = []
        donations_other = []
        donors.each do |donor|

          MultiJson.load(donor["donations_cand"] || "[]").each do |cand|
            donations_cand << cand
          end
          MultiJson.load(donor["donations_party"] || "[]").each do |party|
            donations_party << party
          end
          MultiJson.load(donor["donations_other"] || "[]").each do |other|
            donations_other << other
          end
        end

        donations_cand = donations_cand.sort { |a,b| b["amount"].to_i <=> a["amount"].to_i }.slice(0, num_to_store)
        donations_party = donations_party.sort { |a,b| b["amount"].to_i <=> a["amount"].to_i }.slice(0, num_to_store)
        donations_other = donations_other.sort { |a,b| b["amount"].to_i <=> a["amount"].to_i }.slice(0, num_to_store)

        dollar_repub = totals["dollar_cand_repub"] + totals["dollar_party_repub"]
        dollar_dem = totals["dollar_cand_dem"] + totals["dollar_party_dem"]
        dollar_indy = totals["dollar_cand_indy"] + totals["dollar_party_indy"]
        dollar_other = totals["dollar_cand_other"] + totals["dollar_party_other"]

        # ==== Step 3: process os_527_contribution into donations array and totals
        donations_527 = []
        dollar_527_repub = 0
        dollar_527_dem = 0
        dollar_527_indy = 0
        dollar_527_other = 0
        dollar_527_business = 0
        dollar_527_labor = 0
        dollar_527_ideological = 0
        dollar_527_other = 0

        sql = "
          SELECT Recipient AS name, Date as date, Amount as amount, RecipID as recip_id, RecipCode as recip_code
          FROM os_527_contribution
          WHERE orgname = '#{orgname}' AND RecipCode != ''
        "
        donations = Db.get_rows(sql)

        #==== Get totals from donations, TABLE: donations_pac_pac
        donations.each do |donation|
          amt = donation['amount']

          # Save the donation record + recipient committee to the JSON
          (type, blio, party, status) = OpenSecrets.process_recip_code(donation['recip_code'])

          # Save the donation record + recipient committee to the JSON
          donation_abbrev = {
            :amount => amt,
            :date => donation['date'],
            :recip_name => donation['name'],
            :recip_id => donation['recip_id'],
            :party => donation['party'],
            :type => type,
            :blio => blio,
            :party => party,
            :status => status
          }

          donations_527 << donation_abbrev

          # ==== Get totals from donations, TABLE: donations_pac_pac
          case type
          when /party_committee/
            case party
            when "republican"
              dollar_527_repub += amt
            when "democratic"
              dollar_527_dem += amt
            when "independent / 3rd party"
              dollar_527_indy += amt
            else
              dollar_527_other += amt
            end
          when /outside_committee|other_committee/
            case blio
            when "business"
              dollar_527_business += amt
            when "labor"
              dollar_527_labor += amt
            when "ideological"
              dollar_527_ideological += amt
            else
              dollar_527_other += amt
            end
          end
        end
        donations_527 = donations_527.sort { |a,b| b[:amount].to_i <=> a[:amount].to_i }.slice(0, num_to_store)

        totals = totals.merge({
          "dollar_527_repub" => dollar_527_repub,
          "dollar_527_dem" => dollar_527_dem,
          "dollar_527_indy" => dollar_527_indy,
          "dollar_527_other" => dollar_527_other,
          "dollar_527_business" => dollar_527_business,
          "dollar_527_labor" => dollar_527_labor,
          "dollar_527_ideological" => dollar_527_ideological,
          "dollar_527_other" => dollar_527_other
        })

        dollar_total = 0
        totals.each do |key, amt|
          dollar_total += amt if amt > 0
        end
        dollar_total += dollar_lobby

        sql = "
          INSERT INTO os_summary_orgs
          (
            orgname,
            dollar_lobby,
            donations_cand,
            donations_party,
            donations_other,
            dollar_total,
            dollar_repub,
            dollar_dem,
            dollar_indy,
            dollar_other,
            dollar_cand_repub,
            dollar_cand_dem,
            dollar_cand_indy,
            dollar_cand_other,
            dollar_party_repub,
            dollar_party_dem,
            dollar_party_indy,
            dollar_party_other,
            dollar_other_business,
            dollar_other_labor,
            dollar_other_ideological,
            dollar_other_other,
            dollar_pac_cand_repub,
            dollar_pac_cand_dem,
            dollar_pac_cand_indy,
            dollar_pac_cand_other,
            dollar_pac_pac_repub,
            dollar_pac_pac_dem,
            dollar_pac_pac_indy,
            dollar_pac_pac_other,
            dollar_pac_other_business,
            dollar_pac_other_labor,
            dollar_pac_other_ideological,
            dollar_pac_other_other,
            donations_pac_cand,
            donations_pac_pac,
            donations_pac_other,
            donations_527,
            dollar_527_repub,
            dollar_527_dem,
            dollar_527_indy,
            dollar_527_other,
            dollar_527_business,
            dollar_527_labor,
            dollar_527_ideological
          ) VALUES (
            '#{orgname}',
            #{dollar_lobby},
            '#{MultiJson.dump(donations_cand)}',
            '#{MultiJson.dump(donations_party)}',
            '#{MultiJson.dump(donations_other)}',
            #{dollar_total},
            #{dollar_repub},
            #{dollar_dem},
            #{dollar_indy},
            #{dollar_other},
            #{totals["dollar_cand_repub"]},
            #{totals["dollar_cand_dem"]},
            #{totals["dollar_cand_indy"]},
            #{totals["dollar_cand_other"]},
            #{totals["dollar_party_repub"]},
            #{totals["dollar_party_dem"]},
            #{totals["dollar_party_indy"]},
            #{totals["dollar_party_other"]},
            #{totals["dollar_other_business"]},
            #{totals["dollar_other_labor"]},
            #{totals["dollar_other_ideological"]},
            #{totals["dollar_other_other"]},
            #{totals["dollar_pac_cand_repub"] || 0},
            #{totals["dollar_pac_cand_dem"] || 0},
            #{totals["dollar_pac_cand_indy"] || 0},
            #{totals["dollar_pac_cand_other"] || 0},
            #{totals["dollar_pac_pac_repub"] || 0},
            #{totals["dollar_pac_pac_dem"] || 0},
            #{totals["dollar_pac_pac_indy"] || 0},
            #{totals["dollar_pac_pac_other"] || 0},
            #{totals["dollar_pac_other_business"] || 0},
            #{totals["dollar_pac_other_labor"] || 0},
            #{totals["dollar_pac_other_ideological"] || 0},
            #{totals["dollar_pac_other_other"] || 0},
            '#{MultiJson.dump(donations_pac_cand || [])}',
            '#{MultiJson.dump(donations_pac_pac || [])}',
            '#{MultiJson.dump(donations_pac_other || [])}',
            '#{MultiJson.dump(donations_527) || []}',
            #{totals["dollar_527_repub"]},
            #{totals["dollar_527_dem"]},
            #{totals["dollar_527_indy"]},
            #{totals["dollar_527_other"]},
            #{totals["dollar_527_business"]},
            #{totals["dollar_527_labor"]},
            #{totals["dollar_527_ideological"]}
          )
        "
        Db.exec_sql(sql)
      end
    end
  end

end