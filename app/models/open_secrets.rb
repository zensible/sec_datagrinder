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

  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  # ====== STEP 1: Create os_summary_donor records
  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  def self.prepare_os_summary_donor
    # This should take about 2 hours

    start = Time.now

    DB::log_time(start, "To see progress: SELECT count(id) FROM `os_summary_donors`")
    DB::log_time(start, "== INDEXES: CREATE UNIQUE INDEX contribid_index ON os_summary_donors (ContribID)")
    DB::log_time(start, "== STOP SOLR: bundle exec rake sunspot:solr:stop RAILS_ENV=development  AND  comment it out in os_summary_donors")
    DB::log_time(start, "start")

    db_ver = "os_indiv_1n"

    unless $redis.exists(db_ver)
      $redis.set(db_ver, 1)

      sql = "DELETE FROM os_summary_donors"
      Db.exec_sql(sql)
      #sql = "UPDATE os_individual SET status = 0 WHERE status = 1"
      #Db.exec_sql(sql)
    end

    DB::log_time(start, "after del")

    # Total distinct donors: SELECT count(distinct(contribId)) FROM `os_individual_00` WHERE 1

    # Create empty OsSummaryDonor records, one for each ContribId, a unique identifier for each individual contributor
    # First create records of all the 2016 donors, then 2014 etc
    [ "16", "14", "12", "10", "08", "06", "04", "02", "00", "98", "96", "94", "92", "90" ].each do |year|
      DB::log_time(start, "year #{year}")
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
        DB::log_time(start, "=== prepare start: \n#{sql}")

        rows = Db.get_rows(sql)
        keep_going = rows.length > 1

        Rails.logger.warn Time.new.inspect + " == prepare GO"
        rows.each do |indiv|
          if cnt % 10000 == 0
            DB::log_time(start, "=== prepare row #{cnt}")
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

    DB::log_time(start, "done")
  end

  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  # ====== STEP 2: Populate os_summary_donor records with data
  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  def self.populate_os_summary_donor
    # This took about 30 hours to run for me. You can start/stop it as necessary, it will restart.

    start = Time.now

    # CREATE INDEX contribid_index ON os_individual_90 (ContribID)
    DB::log_time(start, "Process_opensecrets")
    DB::log_time(start, "To see progress: SELECT count(id) FROM `os_summary_donors` WHERE dollar_total != -1")
    DB::log_time(start, "INDEXES: contrib_id on os_individual_**")

    # ALTER TABLE  `os_summary_donors` ADD UNIQUE ( `contrib_id` )

    db_ver = "os_donor_sum_1m"

    unless $redis.exists(db_ver)

      $redis.set(db_ver, 1)

      sql = "UPDATE os_summary_donors SET dollar_total = -1"
      DB::log_time(start, "RESET: #{sql}")
      Db.exec_sql(sql)
    end

    sql = "
      SELECT CmteID, PACShort, Ultorg, RecipCode, PrimCode
      FROM os_committees
      GROUP BY CmteID
      ORDER BY cycle DESC
      "
    DB::log_time(start, "COMMITTEES: #{sql}")
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
    DB::log_time(start, "CANDIDATES: #{sql}")
    candidates = Db.get_rows(sql)

    # Read summary ids/contrib_ids in batches
    num_batch = 1000
    page = 0
    cnt = 0
    keep_going = true

    DB::log_time(start, "Starting")

    while keep_going
      sql = "
        SELECT id, contrib_id
        FROM os_summary_donors
        WHERE dollar_total = -1
        LIMIT 0, #{num_batch}
      " # #   {num_batch * page} 
      donors = Db.get_rows(sql)
      DB::log_time(start, "donors: #{donors}")

      page += 1

      keep_going = donors.length > 1

      DB::log_time(start, "Start batch: #{page * num_batch}\n#{donors[0].inspect}")

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

        [ "90", "92", "94", "96", "98", "00", "02", "04", "06", "08", "10", "12", "14", "16" ].each do |year|  # For each year of info we ave

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
            #DB::log_time(start, "No donors found")
            next
          end

          # For each individual contribution record...
          donations.each_with_index do |donation, i|

            if cnt % 1000 == 0
              DB::log_time(start, "prepare row #{cnt}")
              DB::log_time(start, "Donor: #{donor_summary_id} #{contrib_id}")
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
        DB::log_time(start, "Update: #{donor_summary_id}")
      end # /donor
    end # / keep_going
  end


  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  # ====== STEP 3: Create and populate os_summary_org records
  # ====== ====== ====== ====== ====== ====== ====== ====== ======
  def self.populate_os_summary_org(org = "")
    # This should take about X hours

    start = Time.now

    db_ver = "os_org_sum_2d"

    DB::log_time(start, "starting. Progress: rails c & OsSummaryOrg.count")


    # CREATE INDEX orgname_index ON os_summary_donors (orgname)
    # CREATE INDEX sub_index ON os_lobby_industries (Sub)
    # CREATE INDEX ultorg_index ON os_committees (Ultorg)
    # CREATE INDEX pacid_index ON os_pac_to_candidates (PACID)
    # CREATE INDEX otherid_index ON os_pac_to_pac (Otherid)
    # CREATE INDEX filerid_index ON os_pac_to_pac (Filerid)
    # CREATE INDEX orgname_index ON os_527_contribution (orgname)

    unless $redis.exists(db_ver)
      $redis.set(db_ver, 1)

      sql = "DELETE FROM os_summary_orgs"
      Db.exec_sql(sql)
    end

    DB::log_time(start, "Starting")

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
      DB::log_time(start, "Get 5000 orgs START")
      rows = Db.get_rows(sql)
      keep_going = rows.length > 0 
      DB::log_time(start, "Get 5000 orgs END")

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
        #DB::log_time(start, "get SUMS")
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
        #DB::log_time(start, "Get Sums END")

        ## Get top X donors from each category
        #DB::log_time(start, "Get Donors START")
        sql = "
          SELECT donations_cand, donations_party, donations_other
          FROM os_summary_donors
          WHERE orgname = '#{orgname}'
        "
        donors = Db.get_rows(sql)
        #DB::log_time(start, "Get Donors END")

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