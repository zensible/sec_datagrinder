class Sec
  require 'net/ftp'

  # Step 1: download all form indexes to disk
  def self.get_indices(year_start, year_end, bypass)
    puts "== Logging in"
    ftp = Net::FTP.new('ftp.sec.gov')
    ftp.login("anonymous", "fwee@fwoo.com")
    (year_start..year_end).each do |year|
      (1..4).each do |qtr|
        local_filename = "#{year}_#{qtr}"

        path = "/edgar/full-index/#{year}/QTR#{qtr}"
        files = ftp.chdir(path)
        files = ftp.list('*.gz')
        files.each do |line|
          arr = line.split(/\s+/)
          filename = arr[arr.length - 1]
          next unless filename == "form.gz"
          dir_prefix = "data/sec"
          Dir.mkdir(dir_prefix) unless Dir.exists?(dir_prefix)
          local_path = dir_prefix + "/#{local_filename}.gz"
          unless File.exists?(local_path)
            puts "== Retrieving #{filename} TO #{local_path}"
            ftp.getbinaryfile(filename, local_path) 
            puts "== Unzipping #{local_path} (unzip manually if you get an error here)"
            `gunzip #{local_path}`
          end
        end
      end
    end
    ftp.close
    puts "== Logging out"
  end

  def self.import_forms(year, qtr, bypass)
    sec_ids = []

    idx = "data/sec/#{year}_#{qtr}"
    if !File.exists? idx
      raise "Could not find form index: #{idx}"
    end
    Rails.logger.info("==== Creating records for #{idx}")

    line_num=0
    text = File.open(idx).read
    text.gsub!(/\r\n?/, "\n")   # If you get 'Invalid UTF-8 character' here, open the file in Sublime Text or another editor and go to File -> Save With Encoding -> UTF-8. This happend for me on 2011 qtr 4.
    sta = false
    cnt = 0
    text.each_line do |line|
      if line.match(/^----.*----$/)
        unless line.length == 142
          abort("Invalid fixed column format")
        end
        sta = true
        next
      end
      if sta
        arr = line.split(/\s\s+/)

        form_type = Db.clean2(line[0..11])
        company_name = Db.clean2(line[12..73])
        cik = Db.clean2(line[74..85])
        date_filed = Db.clean2(line[86..97])
        file_name = Db.clean2(line[98..140])

        sec_id = File.basename(file_name)
        sec_id.gsub!(/\.txt$/, "")

        if form_type.match(/SC 13D|SC 13G/) || form_type == "3" || form_type == "4" || form_type == "5"

          # De-dupe
          # Sometimes multiple entities submit the same form with different "reporting" ciks
          # Example: http://www.sec.gov/Archives/edgar/data/1259383/000110465903018308/0001104659-03-018308-index.htm and http://www.sec.gov/Archives/edgar/data/1259382/000110465903018308/0001104659-03-018308-index.htm
          # This prevents us from adding the ownership information twice
          if sec_ids.include?(sec_id)
            Rails.logger.info("==== sec_id already in db: #{sec_id} #{company_name}")
            next
          else
            sec_ids << sec_id
          end

          date_filed = Date.parse(date_filed).to_s(:db)
          puts "== Form #: #{cnt}" if cnt % 100 == 0
          cnt += 1

          Form.create({ :year => year, :quarter => qtr, :form_type => form_type, :company_name => company_name, :cik => cik, :sec_id => sec_id, :date_filed => date_filed, :file_name => file_name, :status => 0 })
        end
      end
    end
  end

  def self.download_forms(year, qtr, bypass)
    puts "========================"
    puts "= Downloading all forms with status == 0, year: #{year}, qtr: #{qtr} OK?"
    puts "========================"
    puts "== Status: "
    puts "== db.getCollection('forms').find({ status: 0 }).count()"
    puts "== db.getCollection('forms').find({ status: 1 }).count()"
    puts "========================"
    ok = $stdin.gets.chomp unless bypass

    #, year: year, quarter: qtr
    forms = Form.any_of({ status: "0", year: year, quarter: qtr }, { status: "-113", year: year, quarter: qtr })
    cnt = 0
    forms.no_timeout.each do |form|
      url = "http://www.sec.gov/Archives/#{form.file_name}"
      puts "== Form #: #{cnt} == #{MultiJson.dump(form)} | #{url}" if cnt % 100 == 0
      cnt += 1

      # Around 12000 records, the SEC starts returning 400s, probably to stop people from overwhelming their servers. This prevents that.
      if (cnt > 0 && cnt % 10000 == 0)
        puts "== At the 10000 record mark, sleeping 5 seconds"
        sleep 5
        cnt = 0
      end

      response = Typhoeus::Request.get(url, followlocation: true)
      if response.code != 200
        puts "== STATUS: -113 (response.code): #{url} =="
        form.status = -113 # non-200
        form.save
        sleep 8
        next
      end

      if form.form_type.match(/SC/)
        txt = response.body
        txt.gsub!(/<PDF>(.+)<\/PDF>/im, "")  # Some forms have enormous PDF documents embedded, skip these since they can't be parsed and we only really care about the metadata

        form.status = 1
        form.txt = txt
      else
        body = response.body.gsub(/\n/, "")
        if (!body.match(/<ownershipDocument.*?>(.*)<\/ownershipDocument>/m))
          # Invalid document: no XML ownershipDocument.
          # ToDo: Try and suss it out from the near-nonsense HTML and TXT data like we do with the SC forms.
          # Since this only occurs with old (pre-2004) individual data that we don't care about quite as much, this has not been done.

          puts "== Pre-2004 individual ownership form #{form.form_type}: #{url}, skipping processing"
          form.status = -114  
          form.txt = txt
          form.save
          next
        end
        xml = "<ownershipDocument>" + body.match(/<ownershipDocument.*?>(.*)<\/ownershipDocument>/m)[1] + "</ownershipDocument>"

        if xml.match(/<\/XML>/)
          form.update_attribute("status", -1) # can't be processed, xml weirdness
          next
        end

        xml = Db.clean_xml(xml)
        str = Hash.from_xml(xml).to_json
        form.status = 1
        form.txt = str
      end
      begin
        form.save
      rescue Exception => exc
        puts "== STATUS: -11 #{url} =="
        form.status = -11 # non-200
        form.txt = ""
        form.save

        msg = "== Couldn't download form #{form.id}: #{exc.message}"
        Rails.logger.error msg
        puts msg
      end
      sleep(0.1)  # Again, helps us avoid errors on the SEC side for throttling
    end

    puts "==== Finished downloading forms to database for #{year} #{qtr}"
    # Pause 5 seconds then download another 10k records
    #sleep(5)
  end

end
