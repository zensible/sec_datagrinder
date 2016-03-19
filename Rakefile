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
    Sec::get_indices(1997, 1997, true)
  end

  task :import_forms => :environment do |t|
    wait_or_start("SEC.2: Create empty forms records in the 'forms' collection in mongodb", "db.getCollection('forms').count()")
    (1997..1997).each do |year|
      Sec::import_forms(year, 1, true)
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

rake sec:download_forms year=1997 qtr=1
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
    wait_or_start("SEC.4: PARSE 'forms' COLLECTION into MajorOwner and DirectOwner records in MongoDB.\n\nBefore running this, be sure to run: rake db:mongoid:create_indexes or you may get a 'Plan executor' error", "db.getCollection('forms').find({ status: 4 }).count()")
    delete_or_continue() {
      puts "=== Deleting owners"
      MajorOwner.delete_all
      DirectOwner.delete_all

      puts "=== Status 4 -> 1"
      Form.where(status: 4).update_all(status: 1)
      puts "=== Done!"
    }

    puts "== Starting ParseOwners"

    # db.getCollection('forms').update( {"status": { "$lt": 0 }}, { $set: { "status": 1 }}, { multi: true })

    # These must go in reverse order so the newest records are represented in the final summary
    1997.downto(1997) do |year|
      1.downto(1) do |qtr|
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
    wait_or_start("SEC.5: Create empty 'summaries' collection in mongodb", "SELECT count(id) FROM summaries")
    delete_or_continue() {
      Summary.destroy_all
    }

    SecProcess.create_summaries(true)
  end

  # At this point, I had to run:
  # db.adminCommand({setParameter: 1, internalQueryExecMaxBlockingSortBytes: 67108864 })

  # I add these manually in robomongo when I get to this step, easier than using mongoid
  # Index required: subj_sec_date
  #{
  #    "subject_cik": 1,
  #    "security_title": 1,
  #    "date_filed" : -1
  #}
  # Index required: issuer_sec_direct_per
  #{
  #    "issuer_cik": 1,
  #    "security_title": 1,
  #    "is_direct_owner" : 1,
  #    "period_of_report" : -1
  #}
  # In order to avoid: Overflow sort stage buffered data usage exceeds internal limit
  task :populate_summaries => :environment do |t|
    wait_or_start("SEC.6: Populate 'summaries' collection in mongodb", "SELECT count(id) FROM summaries WHERE status = 1")
    delete_or_continue() {
      Summary.where(status: 1).update_all({status: 0, owned_by_insider: nil, owned_by_5percent: nil, owner_of_insider: nil, owner_of_5percent: nil})
    }

    SecProcess.populate_summaries(true)
  end

  task :populate_subsidiaries => :environment do |t|
    wait_or_start("SEC.7: Update summaries with subsidiary information from CorpWatch database")
    delete_or_continue() {
      sql = "UPDATE summaries SET subsidiaries = ''"
      Db.exec_sql(sql)
    }
    puts "

Before running,

Use Sequel Pro to import these tables:

cik_name_lookup.sql
company_relations.sql
company_names.sql

FROM:

http://api.corpwatch.org/documentation/db_dump/

Then run:

CREATE INDEX source_cw_id_index ON company_relations (source_cw_id)
CREATE INDEX cw_id_index ON cik_name_lookup (cw_id)
CREATE INDEX cw_id_index ON company_names (cw_id)
"
    CorpWatch::cw_to_summary_go
  end

  def year2to4(year)
    if year.to_i >= 80
      return "19#{year}"
    else
      return "20#{year}"
    end
  end

  task :opensecrets_create_tables => :environment do |t|
    wait_or_start("OS.1: Create and Populate OpenSecrets tables")

    # Prereq: download all files from: https://www.opensecrets.org/MyOS/bulk.php
    # ... into: data/opensecrets -> '527', 'Lobby', and 'campaign' subdirs
    puts "Which group of tables would you like to import?

'527' - 527 group contributions
'lobby' - lobbying data
'campaign' - campaign donations, largest tables by far
"
    mode = $stdin.gets.chomp
    if (mode != 'campaign' && mode != '527' && mode != 'lobby')
      raise "Invalid mode: #{mode}"
    end

    # These table definitions come from the OpenSecrets OpenData User's Guide, specifically the 'schema' at the end: https://www.opensecrets.org/resources/datadictionary/UserGuide.pdf
    # If you get errors when importing data, you may need to adjust the values. If it's numeric, a.k.a '50', that means it's a varchar with a max length of 50. If 'int' it's an integer, 'date' it's a date, 'float' it's a float.
    wait_or_start("OS.1: IMPORT OPENSECRETS TABLES: Mode: #{mode}")
    all_cycles = [ "90", "92", "94", "96", "98", "00", "02", "04", "06", "08", "10", "12", "14", "16" ]
    all_cycles = [ "98" ]
    OpenSecrets.create_and_populate_tables(mode, all_cycles)

    all_cycles.each do |year|
      Db.exec_sql("CREATE INDEX contribid_index ON os_individual_#{year} (ContribID)")
    end

    puts "Done!!"
  end

  task :prepare_os_summary_donor => :environment do |t|
    wait_or_start("OS.2: PREPARE OS SUMMARY DONOR")
    delete_or_continue() {
      sql = "DELETE FROM os_summary_donors"
      Db.exec_sql(sql)
    }

    OpenSecrets::prepare_os_summary_donor([ "98" ])
  end

  # CREATE INDEX orgname_index ON os_summary_donors (orgname);
  # CREATE INDEX sub_index ON os_lobby_industries (Sub);
  # CREATE INDEX ultorg_index ON os_committees (Ultorg);
  # CREATE INDEX pacid_index ON os_pac_to_candidates (PACID);
  # CREATE INDEX otherid_index ON os_pac_to_pac (Otherid);
  # CREATE INDEX filerid_index ON os_pac_to_pac (Filerid);
  # CREATE INDEX orgname_index ON os_527_contribution (orgname);
  task :populate_os_summary_donor => :environment do |t|
    wait_or_start("OS.3: POPULATE OS SUMMARY DONOR", "SELECT count(id) FROM `os_summary_donors` WHERE dollar_total != -1")
    delete_or_continue() {
      sql = "UPDATE os_summary_donors SET dollar_total = -1"
      Db.exec_sql(sql)
    }
    OpenSecrets::populate_os_summary_donor([ "98" ])
  end

  task :populate_os_summary_org => :environment do |t|
    wait_or_start("OS.4: POPULATE OS SUMMARY ORGS")
    delete_or_continue() {
      sql = "DELETE FROM os_summary_orgs"
      Db.exec_sql(sql)
    }
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