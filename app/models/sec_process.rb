class SecProcess

  ################
  #
  # Converts forms into direct and major owners
  #
  ################
  def self.parse_owners(year, quarter, bypass)
    puts "========================"
    puts "= Parsing all owners for forms with status == 1"
    puts "========================"
    ok = $stdin.gets.chomp unless bypass

    # status: 0 - not d/led, 1: downloaded not added to DirectOwner, 2: no no non-derivatives, 3: indirect owner, 3: direct owner, 4: processed, 5: 0 shares
    cnt = 0
    prev = DirectOwner.new()

    #sql = "
    #  SELECT issuer_cik, owner_cik, security_title
    #  FROM direct_owners
    #"
    #dedupe_directowners = Db.get_rows(sql)

    # Should be: all unique issuer_cik + ',' + owner_cik + ',' + security_title

    puts "== loading direct owners"
    directowners_already_added = {}
    DirectOwner.only(:issuer_cik, :owner_cik, :security_title).each do |owner|
      key = "#{owner.owner_cik},#{owner.issuer_cik},#{owner.security_title}"
      directowners_already_added[key] = true
    end

    puts "== loading major owners"
    majorowners_already_added = {}
    MajorOwner.only(:filer_cik, :subject_cik, :security_title, :owner_names).each do |owner|
      key = "#{owner.filer_cik},#{owner.subject_cik},#{owner.security_title},#{owner.owner_names}"
      majorowners_already_added[key] = true
    end

    #while cnt < max_num_to_process
    Rails.logger.info("==== item ##{cnt}: downloaded forms into Direct + MajorOwner")

    badly_formatted_forms = [
      '0001079161-12-000001', # no initial 1.
      '0000812295-12-000084', # 11. not on separate line
      '0001008322-12-000002', # format is fucked
      '0001010412-12-000035', # format is fucked
      '0001010412-12-000105', # what is this I don't even
      '0001010412-12-000108', # what is this I don't even
      '0001381870-12-000002', # Has the sec header twice, weird pgp stuff
      '0001193125-12-298336', # missing labels
      '0001004878-12-000408', # missing data items
      '0001387131-11-000148', # incorrect labels
      '0001381870-11-000004', # bad sec header
    ]

    forms = Form.where( { status: 1, year: year, quarter: quarter }).order_by(:date_filed => :desc)
    if forms.length == 0 || forms.length == 1
      puts "done"
      return true
    end

    forms.each do |form|
      #abort form.inspect
      puts("== Form: #{form.id} == #{form.date_filed} == ")

      #File.open('public/temp.html', 'w') {
      #  |f| f.write(form.txt)
      #}

      if badly_formatted_forms.include?(form.sec_id) || form.sec_id =~ /0001462180-12/ || form.sec_id =~ /0000928464-12/
        form.status = -5
        form.save
        puts "== status -5: badly formatted form"
        next
      end

      if form.txt.nil?
        form.status = -11
        form.save

        #form.update_attribute("status", -11)  # badly formatted or missing information
        puts "== status -11: no form txt"
        next
        #UPDATE `forms` SET status = -11 WHERE txt = null and status = 1
      end

      if form.txt.match(/<PDF>/)
        form.txt.gsub!(/<PDF>(.+)<\/PDF>/im, "")
        form.save
      end

      cnt += 1

      form_id = form._id
      form_sec_id = form.sec_id_from_filename

      #form.status = 4
      #form.save

      #form.update_attribute("status", 4) 
      #  id: #{form_id}
      #  url: http://www.sec.gov/Archives/edgar/data/#{form.cik}/#{form_sec_id.gsub(/-/, '')}/#{form_sec_id}-index.htm
      #  #{form.inspect}
      #  "

      txt = form.txt
      ###############
      #
      # SC* forms
      #
      ###############


      #Statuses:
      #0
      #1
      #5
      #-1 => 0
      #-2 => 0,
      #-3 => 0,
      #-4 => 0,
      #-5 => 0,
      #-7 => 0,
      #-8 => 0,
      #-9 => 0,
      #-10 => 0,
      #-11 => 0,
      #-15 => 0,
      #-17 => 0,

      case form.form_type
      when /^SC /
        obj = form.extract_major_owners
        if obj.nil?  # An error occured and this one must be skipped
          next
        end
        if form.status < 0
          abort form.status.inspect
        end

        header = obj[:header]
        date_filed = header[:date_filed] || ""
        date_filed = Date.parse(header[:date_filed]) || nil

        owner_groups = obj[:owner_groups]

        owner_saved = false
        save_as_group = false

        owner_groups.each do |owners|
          if owners.length > 0
            is_group = (owners.length > 1 ? 1 : 0)
            owner_names = ""
            owners.each do |own|
              owner_names += Db.trim(own[:name]) + "\n"
            end
            #abort group_names.inspect

            # TODO: Instead: create MongoDB document

            key = "#{header[:filer][:cik]},#{header[:subject][:cik]},#{header[:security_title]},#{owner_names}"
            is_latest = majorowners_already_added.include?(key) ? 0 : 1 # If already found, this one is "old"
            next unless is_latest == 1
            majorowners_already_added[key] = true

            mo = MajorOwner.new({ :owner_names => owner_names, :form_id => form_id, :form_sec_id => form_sec_id, :form_type => form.form_type, :date_filed => date_filed, :is_group => is_group, :issuer_name => header[:subject][:issuer_name], :security_title => header[:security_title], :security_cusip => header[:security_cusip], :security_shares => header[:security_shares], :percent_of_class => header[:percent_of_class], :subject_name => header[:subject][:name], :subject_cik => header[:subject][:cik], :subject_irs_number => header[:subject][:irs_number], :subject_state_of_incorporation => header[:subject][:state_of_incorporation], :subject_fiscal_year_end => header[:subject][:fiscal_year_end], :subject_city => header[:subject][:city], :subject_state => header[:subject][:state], :subject_zip => header[:subject][:zip], :filer_name => header[:filer][:name], :filer_cik => header[:filer][:cik], :filer_irs_number => header[:filer][:irs_number], :filer_state_of_incorporation => header[:filer][:state_of_incorporation], :filer_fiscal_year_end => header[:filer][:fiscal_year_end], :filer_city => header[:filer][:city], :filer_state => header[:filer][:state], :filer_zip => header[:filer][:zip], :owners => MultiJson.dump(owners), :header => MultiJson.dump(header), :status => 0, :is_latest => is_latest })

            #abort mo.inspect
            owner_saved = mo.save || owner_saved
            puts("++++ NEW [MAJOR OWNER #{is_latest}] == #{key}")
          else
            puts("++-- SKIP [MAJOR OWNER] (NO OWNERS) == #{key}")
            #abort form.inspect
          end
        end

        if owner_saved
          form.status = 4
          form.save
        else
          # Skipped all new owners
          next
          abort("Could not save: form: #{form}, mowner: #{mo}")
        end

      ############
      #
      # Form 3, 4, 5
      #
      ############
      when /3|4|5/
        obj = MultiJson.load(txt)["ownershipDocument"]

        document_type = obj["documentType"]
        period_of_report = obj["periodOfReport"]

        issuer = obj["issuer"]
        owners = obj["reportingOwner"]
        owners = [ owners ] unless owners.kind_of?(Array)

        if !obj.has_key?("nonDerivativeTable") || obj["nonDerivativeTable"].blank?
          form.status = 2
          form.save

          puts("==== Skipping: only derivative (status 2)")
          next
        end

        # nonDerivativeTable -> nonDerivativeHolding -> ownershipNature -> directOrIndirectOwnership -> value
        nonderiv = obj["nonDerivativeTable"]
        if nonderiv.has_key? "nonDerivativeHolding"
          type = :holding
          holdings = nonderiv["nonDerivativeHolding"]
          #abort "holding: " + form.inspect
        elsif nonderiv.has_key? "nonDerivativeTransaction"
          type = :transaction
          holdings = nonderiv["nonDerivativeTransaction"]
          #abort "transact: " + form.inspect
        end

        # Fix: can sometimes be item instead of array
        holdings = [ holdings ] unless holdings.kind_of?(Array)
        has_direct = false

        # Find diff form types to test for
        if holdings.length > 3
          #form.update_attribute("status", 4)
          #abort "ya: " + MultiJson.dump(form)
        end

        holdings.each do |holding|

          is_direct_owner = holding["ownershipNature"]["directOrIndirectOwnership"]["value"] == "D" ? 1 : 0
          nature_of_ownership = ""
          if is_direct_owner == 0
            nature_of_ownership = holding["ownershipNature"]["natureOfOwnership"]["value"]
            nature_of_ownership = "" if nature_of_ownership.match(/^See\s|Read\s/) || nature_of_ownership.match(/Footnote|footnote/)
          end
          #unless is_direct_owner  #Ignore indirect owners
          #  form.update_attribute("status", 3)
          #  Rails.logger.info("==== Skipping holding: indirect owner")
          #  next
          #end

          #has_direct = true

          security_title = Db.fix_security_title(holding['securityTitle']['value'])

          # security_shares: either the total amount (form 3) or the postTransactionAmounts after stock was bought/sold (form 4)
          if holding.has_key?('postTransactionAmounts')

            if holding['postTransactionAmounts'].has_key?('sharesOwnedFollowingTransaction')
              security_shares = holding['postTransactionAmounts']['sharesOwnedFollowingTransaction']['value']
            else
              if holding['postTransactionAmounts'].has_key?('valueOwnedFollowingTransaction')
                #abort "no sharesowned"
                form.status = 6
                form.save
                Rails.logger.info("==== Skipping holding: no sharesOwnedFollowingTransaction, only valueOwnedFollowingTransaction")
                next
              else
                abort "err 314: novalue either:  #{obj.inspect}"
              end
            end
          else
            abort("err 313: postTransactionAmounts: #{obj.inspect}")
          end

          security_shares = "0" if security_shares == ".00"
          security_shares.gsub!(/\.$/, "") # Remove trailing .
          security_shares = Db.trim(security_shares)
#          security_shares = "1591" if security_shares == ".1591"

          unless security_shares =~ /^\d+$/ || security_shares =~ /^\d+\.\d+$/
            form.status = -1
            form.save


            puts("==== Skipping holding: shares == #{security_shares}")
            next
          end
          security_shares = security_shares.to_i

          #unless security_shares > 0  #Ignore indirect owners
          #  form.update_attribute("status", 5)
          #  Rails.logger.info("==== Skipping holding: 0 shares")
          #  next
          #end

          issuer_cik = issuer['issuerCik']
          issuer_name = issuer['issuerName']
          issuer_symbol = issuer['issuerTradingSymbol'] || nil

          # We only note the first owner's name (usually the reporter), the rest go into owners_all
          owner_cik = owners[0]["reportingOwnerId"]["rptOwnerCik"]
          owner_name = owners[0]["reportingOwnerId"]["rptOwnerName"]
          if owners[0].has_key? "reportingOwnerAddress"
            address = owners[0]["reportingOwnerAddress"]
            if address.kind_of?(Array)
              owner_city = owner_state = owner_zip = nil
            else
              owner_city = address["rptOwnerCity"]
              owner_state = address["rptOwnerState"]
              owner_zip = address["rptOwnerZipCode"]
            end
          else
            owner_city = owner_state = owner_zip = nil
          end

          is_director = owners[0]["reportingOwnerRelationship"]["isDirector"]
          is_officer = owners[0]["reportingOwnerRelationship"]["isOfficer"]
          is_ten_percent = owners[0]["reportingOwnerRelationship"]["isTenPercentOwner"]
          is_other = owners[0]["reportingOwnerRelationship"]["isOther"]

          other_text = ""
          if is_other == "1"
            other_text = owners[0]["reportingOwnerRelationship"]["otherText"]
          end

          owners_all = ""
          if owners.length > 1
            owners_all = MultiJson.dump(owners)
          end

          #dedupe_directowners << { "issuer_cik" => 1271075, "owner_cik" => 1541244, "security_title" => "Common Stock" }
          #dedupe = dedupe_directowners.select {|f| f["issuer_cik"] == issuer_cik.to_i && f["owner_cik"] == owner_cik.to_i && f["security_title"] == security_title }
          key = "#{owner_cik},#{issuer_cik},#{security_title}"
          is_latest = directowners_already_added.include?(key) ? 0 : 1 # If already found, this one is "old"
          next unless is_latest == 1
          directowners_already_added[key] = true

          puts("==== NEW [DIRECT OWNER #{is_latest}] == issuer_cik: #{issuer_cik} owner_cik: #{owner_cik} security_title: #{security_title} ")
          #dedupe_directowners << { "issuer_cik" => issuer_cik.to_i, "owner_cik" => owner_cik.to_i, "security_title" => security_title }

          directowner = DirectOwner.new(
            :is_direct_owner => is_direct_owner,
            :nature_of_ownership => nature_of_ownership,
            :owner_cik => owner_cik,
            :owner_name => owner_name,
            :owner_city => owner_city,
            :owner_state => owner_state,
            :owner_zip => owner_zip,
            :owners_all => owners_all,
            :is_director => is_director,
            :is_officer => is_officer,
            :is_ten_percent => is_ten_percent,
            :is_other => is_other,
            :other_text => other_text,
            :form_id => form_id,
            :form_sec_id => form_sec_id,
            :document_type => document_type,
            :period_of_report => period_of_report,
            :security_title => security_title,
            :security_shares => security_shares,
            :issuer_cik => issuer_cik,
            :issuer_name => issuer_name,
            :issuer_symbol => issuer_symbol,
            :is_latest => is_latest
            )
          # If security is in the same form, same owner, same type of security (e.g. common stock) then we update the previous record's security_shares field instead of inserting a new record
          if prev.document_type.to_s == directowner.document_type.to_s &&
             prev.is_direct_owner.to_s == directowner.is_direct_owner.to_s &&
             prev.form_id.to_s == directowner.form_id.to_s &&
             prev.issuer_cik.to_s == directowner.issuer_cik.to_s &&
             prev.owner_cik.to_s == directowner.owner_cik.to_s &&
             prev.period_of_report.to_s == directowner.period_of_report.to_s &&
             prev.security_title.to_s == directowner.security_title.to_s
            prev[:security_shares] = directowner.security_shares
            prev.save
          else
            # Holding is not a dupe, save it normally
            directowner.save
            prev = directowner
          end
        end # / holdings.each

        #form.update_attribute("status", 4)  # successfully saved to DirectOwner
        #form.status = 4
        #form.save
        form.status = 4
        form.save
      end
      #unless has_direct
      #  form.update_attribute("status", 3)  # Only indirect owners in this form, skip it
      #end

    end

    puts "007 Done!"

    status_stats = {}
    forms = Form.where( { status: 1, year: year, quarter: quarter }).order_by(:date_filed => :desc)
    forms.each do |form|
      status_stats[form.status] ||= 0
      status_stats[form.status] += 1
    end

    puts "Stats: \n\n#{MultiJson.dump(status_stats)}"
    return true

  end

  ##############
  #
  #
  #
  ##############

  def crap_out(type, str)
    abort "#{type}: form_id: #{self.id}, url: http://www.sec.gov/Archives/#{self.file_name}, #{str}"
  end













  def self.create_summaries(bypass)
    # This should only take like 20m

    puts "========================"
    puts "= Creating summaries    "
    puts "========================"
    puts "Status:"
    puts "Summary.count"
    puts "========================"
    ok = $stdin.gets.chomp unless bypass


    #truncate table summaries;
    #ALTER TABLE summaries AUTO_INCREMENT = 1;

    #  # Step 1: Get all distinct 5%+ owners
    #  rows = Db.get_rows("
    #    SELECT subject_cik, subject_name, subject_irs_number, subject_state_of_incorporation, subject_city, subject_state, subject_zip
    #    FROM major_owners
    #    WHERE subject_cik NOT IN (SELECT cik FROM summaries)
    #    GROUP BY subject_cik
    #    ORDER BY date_filed desc
    #    ")
    summary_ciks = {}
    Summary.select("cik").all.each do |doc|
      summary_ciks[doc.cik] = true
    end

    Rails.logger.info("==== prepare_records 1.start")
    # Step 1: Get all distinct 5%+ owners
    MajorOwner.only(:subject_cik, :subject_name, :subject_irs_number, :subject_state_of_incorporation, :subject_city, :subject_state, :subject_zip, :date_filed).desc(:date_filed).each do |doc|
      next if summary_ciks[doc.subject_cik]
      summary_ciks[doc.subject_cik] = true

      # Store all variations on the company's name
      arr = MajorOwner.where({ "subject_cik" => doc.subject_cik}).distinct(:subject_name)
      all_names = []
      if arr.length > 1
        names_hsh = {}
        arr.each do |nam|
          key = nam.gsub(/\W/, "")
          key = key.downcase()
          if !names_hsh[key]
            all_names.push(nam)
          end
          names_hsh[key] = true
        end
        puts doc.subject_name
        puts all_names.inspect
      end
      summ = Summary.create({
        :cik => doc.subject_cik,
        :name => doc.subject_name, # Since we sort by date, newest company name ends up here
        :all_names => (all_names.length > 1 ? MultiJson.dump(all_names) : nil),
        :irs_number => doc.subject_irs_number,
        :cusip => doc.security_cusip,
        :state_inc => doc.subject_state_of_incorporation,
        :city => doc.subject_city,
        :state => doc.subject_state,
        :zip => doc.subject_zip,
        :subtype => 1,
        :symbol => Db.cik_to_symbol(doc.subject_cik)
        })
    end

    Rails.logger.info("==== prepare_records 2.start")
    # Step 2: get all companies w/ direct owners only, no major
    DirectOwner.only(:issuer_cik, :issuer_name, :issuer_cik).desc(:period_of_report).each do |doc|
      next if summary_ciks[doc.issuer_cik]
      summary_ciks[doc.issuer_cik] = true

      summ = Summary.create({
        :cik => doc.issuer_cik,
        :name => doc.issuer_name,
        :irs_number => '',
        :cusip => '',
        :state_inc => '',
        :city => '',
        :state => '',
        :zip => '',
        :subtype => 2,
        :symbol => doc.issuer_cik
        })
    end

    Rails.logger.info("==== prepare_records 3.start")
    # Step 3: get all non-public companies and mega-rich owners
    MajorOwner.only(:filer_cik, :filer_name, :filer_irs_number, :filer_state_of_incorporation, :filer_city, :filer_state, :filer_zip).desc(:date_filed).each do |doc|
      next if summary_ciks[doc.filer_cik]
      summary_ciks[doc.filer_cik] = true

      summ = Summary.create({
        :cik => doc.filer_cik,
        :name => doc.filer_name,
        :irs_number => doc.filer_irs_number,
        :cusip => '',
        :state_inc => doc.filer_state_of_incorporation,
        :city => doc.filer_city,
        :state => doc.filer_state,
        :zip => doc.filer_zip,
        :subtype => 3,
        :symbol => Db.cik_to_symbol(doc.filer_cik)
        })
      #abort summ.inspect
    end

    Rails.logger.info("==== prepare_records 4.start")
    # Step 4: get all workin' stiffs (e.g. insider owners w/o 5%+ entries)
    DirectOwner.only(:owner_cik, :owner_name, :owner_city, :owner_state, :owner_zip).desc(:period_of_report).each do |doc|
      next if summary_ciks[doc.owner_cik]
      summary_ciks[doc.owner_cik] = true

      summ = Summary.create({
        :cik => doc.owner_cik,
        :name => doc.owner_name,
        :irs_number => '',
        :cusip => '',
        :state_inc => '',
        :city => doc.owner_city,
        :state => doc.owner_state,
        :zip => doc.owner_zip,
        :subtype => 4,
        :symbol => ''
        })
      #abort summ.inspect
    end

  end

  def self.populate_summaries(bypass)

    puts "========================"
    puts "= Populating summaries    "
    puts "========================"
    puts "Status:"
    puts "db.summaries.find({status: 1, owned_by_5percent: { $ne: '[]' } }).count()"
    puts "db.summaries.find({status: 1, owned_by_insider: { $ne: '[]' } })"
    puts "db.summaries.find({status: 1, owner_of_5percent: { $ne: '[]' } })"
    puts "db.summaries.find({status: 1, owner_of_insider: { $ne: '[]' } })"
    puts "db.summaries.count({status: 1})"
    puts "========================"
    ok = $stdin.gets.chomp unless bypass
    cnt = 0
    Summary.where(:status => 0).find_each do |sum|
      owned_by_insider = []

      cnt += 1
      if cnt % 1000 == 0
        puts "== line: #{cnt}. #{sum.inspect}"
      end

      cik = sum.cik

      dos1 = DirectOwner.where(issuer_cik: cik).asc(:owner_cik, :security_title, :is_direct_owner).desc(:period_of_report)
      dos1 = filter_owner_arr(:do, dos1, ["owner_cik", "security_title", "is_direct_owner"])
      dos1.sort! { |a,b| b.security_shares <=> a.security_shares }
      sum.owned_by_insider = MultiJson.dump(dos1)

      mos1 = MajorOwner.where(subject_cik: cik).asc(:filer_cik, :security_title).desc(:date_filed)
      mos1 = filter_owner_arr(:mo, mos1, ["filer_cik", "security_title"])
      mos1.sort! { |a,b| b.security_shares <=> a.security_shares }
      sum.owned_by_5percent = MultiJson.dump(mos1)

      dos2 = DirectOwner.where(owner_cik: cik).asc(:issuer_cik, :security_title, :is_direct_owner).desc(:period_of_report)
      dos2 = filter_owner_arr(:do, dos2, ["owner_cik", "security_title", "is_direct_owner"])
      dos2.sort! { |a,b| a.issuer_name <=> b.issuer_name }
      sum.owner_of_insider = MultiJson.dump(dos2)

      mos2 = MajorOwner.where(filer_cik: cik).asc(:subject_cik, :security_title).desc(:date_filed)
      mos2 = filter_owner_arr(:mo, mos2, ["subject_cik", "security_title"])
      mos2.sort! { |a,b| a.subject_name.to_s <=> b.subject_name.to_s }
      sum.owner_of_5percent = MultiJson.dump(mos2)

      ### ToDo: paginate subsidiaries as well

      sum.status = 1
      sum.num_filings = dos1.length + dos2.length + mos1.length + mos2.length
      if (dos2.length + mos1.length + mos2.length) == 0 && sum.subtype == 4
        # Ignore indiv insiders w/o ownership
        sum.delete
      else
        sum.save
      end
    end # /summaries
  end

  # Take array of owners, filter by given field names being the same
  def self.filter_owner_arr(typ, arr, filter_by)
    result_ids = []
    prev = nil
    arr.no_timeout.each do |owner|
      save_it = false
      filter_by.each do |filter|
        if prev.nil? || owner[filter] != prev[filter]
          #abort "diff: filter: #{filter}\n\n" + owner[filter].to_s + "\n\n\n" + prev[filter].to_s + "\n\n\n" + owner.inspect + "\n\n\n" + prev.inspect
          save_it = true
          break
        end
      end
      if save_it
        Rails.logger.warn("++++ SAVE #{MultiJson.dump(owner)}")
      else
        Rails.logger.warn("---- SKIP #{MultiJson.dump(owner)}")
      end
      result_ids << owner.id if save_it
      prev = owner
    end

    if result_ids.length > 0
      ids = result_ids.join(", ")
      if typ == :do
        #dos1 = DirectOwner.where(issuer_cik: cik).asc(:owner_cik, :security_title, :is_direct_owner).desc(:period_of_report)

        arr = []
        DirectOwner.any_in(id: result_ids).where(:security_shares.gt => 0).each do |down|
          arr << down
        end
        return arr
        #.find_by_sql("
        #  SELECT form_id, form_sec_id, is_direct_owner, owner_cik, owner_name, owner_city, owner_state, owner_zip, is_director, is_officer, is_ten_percent, is_other, period_of_report, issuer_cik, issuer_name, issuer_symbol, security_title, security_shares
        #  FROM direct_owners
        #  WHERE id IN (#{ids}) AND security_shares > 0
        #  ")
      else
        arr = []
        MajorOwner.any_in(id: result_ids).where(:security_shares.gt => 0).each do |down|
          arr << down
        end
        return arr
        #return MajorOwner.find_by_sql("
        #  SELECT form_id, form_sec_id, date_filed, owner_names, security_title, security_shares, percent_of_class, subject_name, subject_cik, subject_irs_number, subject_state_of_incorporation, subject_city, subject_state, subject_zip, filer_name, filer_cik, filer_irs_number, filer_city, filer_state, filer_zip, filer_state_of_incorporation, header, owners
        #  FROM major_owners
        #  WHERE id IN (#{ids}) AND security_shares > 0
        #  ")
      end
    else
      return []
    end
  end

end