#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

#
# brew services start mongodb
#
#
#

require File.expand_path('../config/application', __FILE__)
require 'csv'
require 'iconv'

DataGrinder::Application.load_tasks

def wait_or_start(name, status = "")
  puts "\n\n"
  puts "========================================================================================"
  puts "==== [#{name}] in 4s. Ctrl-break to stop"
  puts "========================================================================================"
  puts "\n\n"
  sleep(4)
  unless status.blank?
    puts "\n\n====== For current status, run:\n\n#{status}\n\n"
  end
  sleep(2)
end

def delete_or_continue()
  puts "== To delete all records before running this job, type 'yes' and hit enter, otherwise type 'no'"
  ok = ''
  while ok.blank?
    ok = $stdin.gets.chomp
  end
  if ok == "yes"
    puts "==== DELETE chosen, waiting 4 seconds. Hit ctrl + break to cancel."
    sleep(4)
    puts "== Deleting!"
    yield()
  else
    puts "== Continue"
  end
end

namespace :sec do

  task :get_indices => :environment do |t|
    wait_or_start("SEC.1: Import forms 'index' files to data/sec/form from the EDGAR FTP site.")
    Sec::get_indices(1994, 1994, true)
  end

  task :import_forms => :environment do |t|
    wait_or_start("SEC.2: Create empty forms records in the 'forms' collection in mongodb", "db.getCollection('forms').count()")
    (1994..1994).each do |year|
      Sec::import_forms(year, 1, true)
      Sec::import_forms(year, 2, true)
      Sec::import_forms(year, 3, true)
      Sec::import_forms(year, 4, true)
    end
  end

  # By far the slowest part of the process. You'll want to run several of these at once.
  #
  # Forms default to '0' for status. When the form content is downloaded, we switch it to '1', 'ready for processing'
  task :download_forms => :environment do |t|
    wait_or_start("SEC.3: DOWNLOAD CONTENT OF 'forms' INTO forms.txt COLLECTION IN MONGODB. Year: #{ENV['year']}, quarter: #{ENV['qtr']}", "db.getCollection('forms').find({ status: 1 }).count()")

    if ENV['year'].blank? || ENV['qtr'].blank?
      abort "
Syntax:

rake sec:download_forms year=1994 qtr=1
      "
    end

    Sec::download_forms(ENV['year'], ENV['qtr'], true)
  end

  # Once you've downloaded all forms, you should back up your forms collection in case something goes wrong in later steps
  task :backup => :environment do |t|
    puts "
To back up your forms database, run this command in the rails directory:

mongodump --out backup/ --host 127.0.0.1 --db data_grinder_development
"
  end

  # When we successfully parse status = 1 records, we set them to status = 4
  task :parse_owners => :environment do |t|
    wait_or_start("SEC.4: PARSE 'forms' COLLECTION into MajorOwner and DirectOwner records in MongoDB.  Before running this, be sure to run: rake db:mongoid:create_indexes or you may get a 'Plan executor' error", "db.getCollection('forms').find({ status: 4 }).count()")
    delete_or_continue() {
      puts "=== Deleting owners"
      MajorOwner.delete_all
      DirectOwner.delete_all

      puts "=== Status 4 -> 1"
      Form.where(status: 4).update_all(status: 1)
      puts "=== Done!"
    }

    puts "== Starting ParseOwners"

    1994.downto(1994) do |year|
      4.downto(1) do |qtr|
        rv = SecProcess.parse_owners(year, qtr, true)
        if (rv != true)
          puts "== Could not import: #{year} #{qtr}!!"
          break
        end
      end
    end

    #SecProcess.parse_owners(2013, 2, 300, 1000000, true)
    #SecProcess.parse_owners(2013, 3, 300, 1000000, true)
    #SecProcess.parse_owners(2013, 4, 300, 1000000, true)
    puts "++ DIRECTOWNERS: " + DirectOwner.count.to_s
    puts "++ MAJOROWNERS: " + MajorOwner.count.to_s
  end

  task :create_summaries => :environment do |t|
    wait_or_start("SEC.5: Create empty 'summaries' collection in mongodb")

    db_ver = "create_summaries_1d"

    if $redis.exists(db_ver)
      puts "==== Skip delete"
    else
      puts "==== CLEAR SUMMARY COLLECTIONS in 2s. Ctrl-break to cancel"
      sleep(2)

      $redis.set(db_ver, 1)
      Summary.destroy_all
    end

    SecProcess.create_summaries(true)
  end

  # At this point, I had to run:
  # db.adminCommand({setParameter: 1, internalQueryExecMaxBlockingSortBytes: 67108864 })
  # In order to avoid: Overflow sort stage buffered data usage exceeds internal limit
  task :populate_summaries => :environment do |t|
    wait_or_start("SEC.6: Populate 'summaries' collection in mongodb")

    db_ver = "populate_summaries_1c"

    if $redis.exists(db_ver)
      puts "==== Skip delete"
    else
      puts "==== CLEAR SUMMARY COLLECTIONS in 2s"
      sleep(2)

      $redis.set(db_ver, 1)
      Summary.where(status: 1).update_all({status: 0, owned_by_insider: nil, owned_by_5percent: nil, owner_of_insider: nil, owner_of_5percent: nil})
    end

    SecProcess.populate_summaries(true)
  end


  task :corpwatch_updates => :environment do |t|
    wait_or_start("SEC.7: ")
    puts "

Before running,

Import:

cik_name_lookup.sql
company_relations.sql
company_names.sql

FROM:

http://api.corpwatch.org/documentation/db_dump/

And run:

CREATE INDEX source_cw_id_index ON company_relations (source_cw_id)
CREATE INDEX cw_id_index ON cik_name_lookup (cw_id)
CREATE INDEX cw_id_index ON company_names (cw_id)

"
    CorpWatch::cw_to_summary_go
  end

  # Reads db_backups/forms.sql full backup into form_year_qtr tables
  task :read_backup => :environment do |t|

    #ActiveRecord::Base.connection.execute("DELETE FROM forms")
    path = "/Users/justin.sante/datagrinder/forms_2013_1.sql"
    file = File.open(path)
    start_at = 0
    cur = 0
    ActiveRecord::Base.connection.execute("DELETE FROM forms_2013_1")
    while (cur_line = file.gets)
      cur += 1
      puts "== #{cur} =="
      next if cur < start_at
      if cur_line.match(/VALUES \(\d+,(\d\d\d\d),(\d),/)
        cur_line = cur_line.sub(/INSERT INTO `forms`/, "INSERT INTO `forms_#{$1}_#{$2}`")
      else
        abort "No year/quarter: " + cur_line
      end
      #if cur_line.match(/\);$/)
        begin
          ActiveRecord::Base.connection.execute(cur_line)
        rescue Exception => e
          puts "ERR: #{e} line: #{cur_line.slice(0, 1000)}"
          abort "done"
        end
      #else
      #  puts "Could not import: #{cur_line.slice(0, 1000)}"
      #end
    end
    file.close
  end

  def year2to4(year)
    if year.to_i >= 80
      return "19#{year}"
    else
      return "20#{year}"
    end
  end

  task :opensecrets_create_tables => :environment do |t|
    # https://www.opensecrets.org/MyOS/bulk.php

    # Warning: some pre-processing required
    # As of 6/15/2013, the Campaign Finance files: pacs##.txt omit the pipes around a few of the fields:
    #
    # |2012|,|4110320111144771184|,|C00102160|,|N00025025|,2000,09/13/2011,|E1620|,|24K|,|D|,|H2PA06114|
    # Should be:
    # |2012|,|4110320111144771184|,|C00102160|,|N00025025|,|2000|,|09/13/2011|,|E1620|,|24K|,|D|,|H2PA06114|
    #
    # Running this search/replace in an editor such as EditpadPro and saving will fix them:
    #\|,(-?)(\d+),(\d\d)\/(\d\d)\/(\d\d\d\d),\|
    #|,|\1|,|\2/\3/\4|,|
    #

#sed 's~\|,\(-?\)\(\d+\),\(\d\d\)\/\(\d\d\)\/\(\d\d\d\d\),\|~|,|\1|,|\2/\3/\4|,|~g' test.txt
#sed "s~\d~a~g" test.txt
#echo day | sed s/day/night/ 
#sed -E 's~[0-9]~a~g' test.txt

    # Stray quote errors:
    # indivs08.txt: Missing or stray quote in line 1854485

    puts "Which group of tables would you like to import?

'campaign' - largest by far
'527' - 527 group contributions
'lobby' - lobbying data
"
    mode = $stdin.gets.chomp
    if (mode != 'campaign' && mode != '527' && mode != 'lobby')
      raise "Invalid mode: #{mode}"
    end

    wait_or_start("OS.1: IMPORT OPENSECRETS TABLES: Mode: #{mode}")
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
    #  "os_pac_to_pac" => "pac_other",
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

    all_cycles = [ "90", "92", "94", "96", "98", "00", "02", "04", "06", "08", "10", "12", "14", "16" ]

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

#abort files.inspect
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
          DB.exec_sql(sql.gsub("os_individual", "os_individual_" + year))
        end
      else
        puts sql
        DB.exec_sql(sql)
      end

    end

#sql = "
#INSERT INTO os_individual_00_sorted2 (
#  SELECT Cycle, FECTransId, ContribID, Contrib, RecipID, Orgname, UltOrg, RealCode, DateOf, Amount, Street, City, State, Zip, RecipCode, Type, CmteID, OtherID, Gender, Microfilm, Occupation, Employer, Source, status
#  FROM os_individual_00
#  WHERE ContribID != ''
#  ORDER BY ContribID, DateOf DESC
# )
#{}"

#{}"
#        DB.exec_sql(sql)

    #ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
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

          # Exceptions for 'indivs', only year "12" matches the exact schema in UserGuide.doc
          #if mode == "campaign" && filename == "indivs" && [ "90", "92", "94", "96", "98", "00", "02", "04", "06", "08", "10", "14", "16" ].include?(year)
          #  if values[19].nil?
          #    puts("== invalid employer_position: #{values.inspect}")
          #    next
          #  else
          #    employer_position = values[19]
          #    arr = employer_position.split("/")
          #    values.delete_at(19)
          #    if arr.length > 0 && values[21].blank?
          #      values[21] = arr[0]
          #    end
          #    if arr.length > 1 && values[20].blank?
          #      values[20] = arr[1] # May miss >1 slash in combined field
          #    end
          #  end
          #end

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
                val = "#{year2to4(year)}-1-1"
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
            DB.exec_sql(sql)
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

    puts "Done!!"
  end

  task :prepare_os_summary_donor => :environment do |t|
    wait_or_start("OS.2: PREPARE OS SUMMARY DONOR")
    OpenSecrets::prepare_os_summary_donor()
  end

  task :populate_os_summary_donor => :environment do |t|
    wait_or_start("OS.3: POPULATE OS SUMMARY DONOR")
    OpenSecrets::populate_os_summary_donor()
  end

  task :populate_os_summary_org => :environment do |t|
    wait_or_start("OS.4: POPULATE OS SUMMARY ORGS")
    OpenSecrets::populate_os_summary_org()
  end

  task :import_export do |t|
    puts "
Done!

Now use Sequel Pro to output these tables to .sql, including create/drop syntax:

company_names
os_summary_donors
os_summary_orgs
summaries

You may also want to:

rake log:clear

Zip up the .sql file
mv datagrinder_development_2016-03-18.sql.zip to ./public
ngrok 3000

Server-side:

wget http://31a2210.ngrok.com/datagrinder_development_2016-03-18.sql.zip
unzip datagrinder_development_2016-03-18.sql.zip

This step takes several hours of downtime:

mysql aidb_production -u root -pTHR

RENAME TABLE company_names TO bak_company_names;
RENAME TABLE os_summary_donors TO bak_os_summary_donors;
RENAME TABLE os_summary_orgs TO bak_os_summary_orgs;
RENAME TABLE summaries TO bak_summary;

mysql aidb_production -u root -pTHR < datagrinder_development_2016-03-18.sql
cd /rails/aidb
RAILS_ENV=production rake sunspot:solr:reindex
"
  end


end