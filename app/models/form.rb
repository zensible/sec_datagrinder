# encoding: UTF-8
class Form
  include Mongoid::Document

  field :year, type: Integer
  field :quarter, type: Integer
  field :form_type, type:  String
  field :company_name, type:  String
  field :cik, type: Integer
  field :sec_id, type:  String
  field :date_filed, type:  Date
  field :file_name, type:  String
  field :txt, type:  String
  field :status, type: Integer, default: 0

  index({ date_filed: -1 }, { unique: false, name: "form_date_filed_index_neg" })
  index({ date_filed: 1 }, { unique: false, name: "form_date_filed_index" })
  index({ status: 1 }, { unique: false, name: "form_status_index" })
  index({ cik: 1 }, { unique: false, name: "form_cik_index" })
  index({ year: 1 }, { unique: false, name: "form_year_index" })
  index({ quarter: 1 }, { unique: false, name: "form_quarter_index" })

  def sec_id_from_filename
    fn = File.basename(file_name)
    return fn.gsub(/\.txt$/, "")
  end

  def crap_out(*arr)
    abort arr.inspect
  end

  def extract_major_owners
    debug_mode = false

    sec_header = self.txt.match(/<SEC-HEADER.*?>(.*)<\/SEC-HEADER>/m)
    if sec_header.nil?
      sec_header = self.txt.match(/<IMS-HEADER.*?>(.*)<\/IMS-HEADER>/m)
    end
    if sec_header.nil?
      puts "=== Skipping #{self.id}: no header information so we can't determine owner"
      self.status = -10
      self.save
      return nil
    end
    sec_header = sec_header[1]

    mode_lvl1 = nil
    mode_lvl2 = nil
    document_count = -1
    date_filed = ""
    group_members = []
    subject = {}
    filer = {}
    subject[:former] = []
    filer[:former] = []

    # Step 1: parse sec_header
    sec_header.split(/\n/).each do |line|
      if line.match(/:/)
        line = Db.trim(line)

        arr = line.split(":")
        if arr.length == 1  # Blarg:
          str = Db.trim(arr[0])

          case str
          when "SUBJECT COMPANY"
            mode_lvl1 = :subject_company
          when "FILED BY"
            mode_lvl1 = :filed_by
          when "COMPANY DATA"
            mode_lvl2 = :company_data
          when "FILING VALUES"
            mode_lvl2 = :filing_values
          when "BUSINESS ADDRESS"
            mode_lvl2 = :business_address
          when "MAIL ADDRESS"
            mode_lvl2 = :mail_address
          when "FORMER COMPANY"
            mode_lvl2 = :former_company
          when "CONFIRMING COPY"
            next
          else
            puts "Unknown header field: #{str}"
            #if debug_mode
            #  crap_out("NO OWNERSHIP TABLES (1. name, 11. aggregate, 13. percent)", "lines_txt: #{lines_txt}")
            #else
            #  self.status = -8
            #  self.save
            #  return nil
            #end
          end
        end
        if arr.length == 2  # key: val
          (key, val) = arr
          key = Db.trim(key)
          val = Db.trim(val)
          if key.match(/\.hdr\.sgml/)
            next
          end

          case key
          when /\.hdr\.sgml|ACCESSION NUMBER|CONFORMED SUBMISSION TYPE|DATE AS OF CHANGE|DATE OF NAME CHANGE/
            next # skip these, who carez
          when /PUBLIC DOCUMENT COUNT/
            document_count = val
          when /FILED AS OF DATE/
            date_filed = val
          when /GROUP MEMBERS/
            group_members << val
          when /FORMER CONFORMED NAME/
            subject[:former] << val if mode_lvl1 == :subject_company
            filer[:former] << val if mode_lvl1 == :filed_by
          when /COMPANY CONFORMED NAME/
            subject[:name] = val if mode_lvl1 == :subject_company
            filer[:name] = val if mode_lvl1 == :filed_by
          when /CENTRAL INDEX KEY/
            subject[:cik] = val if mode_lvl1 == :subject_company
            filer[:cik] = val if mode_lvl1 == :filed_by
          when /STANDARD INDUSTRIAL CLASSIFICATION/
            subject[:sic] = val if mode_lvl1 == :subject_company
            filer[:sic] = val if mode_lvl1 == :filed_by
          when /IRS NUMBER/
            subject[:irs_number] = val if mode_lvl1 == :subject_company
            filer[:irs_number] = val if mode_lvl1 == :filed_by
          when /STATE OF INCORPORATION/
            subject[:state_of_incorporation] = val if mode_lvl1 == :subject_company
            filer[:state_of_incorporation] = val if mode_lvl1 == :filed_by
          when /FISCAL YEAR END/
            subject[:fiscal_year_end] = val if mode_lvl1 == :subject_company
            filer[:fiscal_year_end] = val if mode_lvl1 == :filed_by
          when /FORM TYPE/
            subject[:form_type] = val if mode_lvl1 == :subject_company
            filer[:form_type] = val if mode_lvl1 == :filed_by
          when /SEC ACT/
            subject[:sec_act] = val if mode_lvl1 == :subject_company
            filer[:sec_act] = val if mode_lvl1 == :filed_by
          when /SEC FILE NUMBER/
            subject[:sec_file_number] = val if mode_lvl1 == :subject_company
            filer[:sec_file_number] = val if mode_lvl1 == :filed_by
          when /FILM NUMBER/
            subject[:film_number] = val if mode_lvl1 == :subject_company
            filer[:film_number] = val if mode_lvl1 == :filed_by
          when /STREET 1/
            subject[:street1] = val if mode_lvl1 == :subject_company && mode_lvl2 == :business_address
            filer[:street1] = val if mode_lvl1 == :filed_by && mode_lvl2 == :business_address
          when /STREET 2/
            subject[:street2] = val if mode_lvl1 == :subject_company && mode_lvl2 == :business_address
            filer[:street2] = val if mode_lvl1 == :filed_by && mode_lvl2 == :business_address
          when /CITY/
            subject[:city] = val if mode_lvl1 == :subject_company && mode_lvl2 == :business_address
            filer[:city] = val if mode_lvl1 == :filed_by && mode_lvl2 == :business_address
          when /STATE/
            subject[:state] = val if mode_lvl1 == :subject_company && mode_lvl2 == :business_address
            filer[:state] = val if mode_lvl1 == :filed_by && mode_lvl2 == :business_address
          when /ZIP/
            subject[:zip] = val if mode_lvl1 == :subject_company && mode_lvl2 == :business_address
            filer[:zip] = val if mode_lvl1 == :filed_by && mode_lvl2 == :business_address
          when /BUSINESS PHONE/
            subject[:business_phone] = val if mode_lvl1 == :subject_company && mode_lvl2 == :business_address
            filer[:business_phone] = val if mode_lvl1 == :filed_by && mode_lvl2 == :business_address
          else
            #if debug_mode
              puts "PARSE SEC HEADER: Unknown key: " + key + ", val: " + val
            #else
            #  self.status = -9
            #  self.save
            #  return nil
            #end
          end
        end
        if arr.length > 2
          #abort "#{JSON.pretty_generate(arr)}"
        end
      end
    end
    sec_header = {
      :date_filed => date_filed,
      :group_members => group_members,
      :subject => subject,
      :filer => filer
    }

    # Strip pdf attachments
    if self.txt.match(/<PDF>/)
      self.txt.gsub!(/<PDF>(.+)<\/PDF>/im, "")
    end



    ##############
    #
    # Step 1: strip all html, get an array of lines
    #
    ##############
    puts "http://www.sec.gov/Archives/#{self.file_name}"
    lines_txt = Db.txt_to_lines(self.txt)
    if lines_txt.nil? # effed up badly
      self.status = -10
      self.save
      return nil
    end

    # filter out noise
    lines_txt = lines_txt.gsub(/<!--(.+?)-->/, "")
    lines_txt = lines_txt.gsub(/&nbsp;|&#160;/, " ")
    lines_txt = lines_txt.gsub(/Number\s+of\s+shares\s+beneficially\s+owned\s+by\s+each\s+reporting\s+person\s+with\s*/mi, "")
    lines_txt = lines_txt.gsub(/number\s+of\s+shares/mi, "")
    lines_txt = lines_txt.gsub(/beneficially\s+owned\s+by/mi, "")
    lines_txt = lines_txt.gsub(/each\s+reporting/mi, "")
    lines_txt = lines_txt.gsub(/person\s+with/mi, "")
    lines_txt = lines_txt.gsub(/\npage\W+\d+\n/mi, "\n")
    lines_txt = lines_txt.gsub(/\npage\W+\d+\W+of\W+\d+\n/mi, "\n")
    lines_txt = lines_txt.gsub(/\(see\W+item\W+\d+\)/mi, "")
    lines_txt = lines_txt.gsub(/\n_+\n/i, "\n\n")
    lines_txt = lines_txt.gsub(/\n-+\n/i, "\n\n")

    lines_txt = lines_txt.gsub(/\n+/, "\n")

    type = "D"
    if self.form_type.match(/13G/)
      type = "G" 
    else
      type = "D"
    end

    if type == "D" && lines_txt.match(/12(.*)(\s+)type(s*) of reporting person/i)
      type = "G"
      #self.update_attribute("status", "-6")
      #return nil
    end

    if type == "G" && lines_txt.match(/14(.*)(\s+)type(s*) of reporting person/i)
      type = "D"
      #return nil
    end

    # Accounts for occasional format
    if type == "G" && lines_txt.match(/\nItem 1:/i)
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+1:\s+Reporting\s+Person\s+-\s+/, "\nItem 1:")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+1:/, "1. Name of Reporting Person\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+4:/, "4. CITIZENSHIP OF PLACE OF ORGANIZATION\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+5:/, "5. SOLE VOTING POWER\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+6:/, "6. SHARED VOTING POWER\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+7:/, "7. SOLE DISPOSITIVE POWER\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+8:/, "8. SHARED DISPOSITIVE POWER\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+9:/, "9. AGGREGATE AMOUNT BENEFICIALLY OWNED BY EACH REPORTING PERSON\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+10:/, "10. CHECK IF THE AGGREGATE AMOUNT IN ROW (9) EXCLUDES CERTAIN SHARES\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+11:/, "11. PERCENT OF CLASS REPRESENTED BY AMOUNT IN ROW (9)\n")
      lines_txt = lines_txt.gsub(/^(\W*)Item\s+12:/, "12. TYPE OF REPORTING PERSON\n")
    end

    ##############
    #
    # Step 2: filter into header and owner tables, discard the rest
    #
    ##############

    # Special cases for annoying filers
    lines_txt = lines_txt.gsub(/^(\W*)1(\W+)1Name of report/im, "1. Name of report")
    lines_txt = lines_txt.gsub(/^(\W*)1(\W+)\(a\) Name/im, "1. Name")
    lines_txt = lines_txt.gsub(/^(\W*)1\n2(\W+)Type of reporting/im, "12. Type of reporting")
    lines_txt = lines_txt.gsub(/T ype of Reporting/, "Type of Reporting")

    lines_txt = lines_txt.gsub(/^(\W*)1(\W+)Name/im, "1. Name")
    lines_txt = lines_txt.gsub(/^(\W*)2(\W+)Check/im, "2. Check")
    lines_txt = lines_txt.gsub(/^(\W*)3(\W+)SEC/im, "3. SEC")
    if type == "D"
      lines_txt = lines_txt.gsub(/^(\W*)4(\W+)Source/im, "4. Source")
      lines_txt = lines_txt.gsub(/^(\W*)5(\W+)Check/im, "5. Check")
      lines_txt = lines_txt.gsub(/^(\W*)6(\W+)Citizen/im, "6. Citizen")
      lines_txt = lines_txt.gsub(/^(\W*)7(\W+)Sole/im, "7. Sole")
      lines_txt = lines_txt.gsub(/^(\W*)8(\W+)Share/im, "8. Share")
      lines_txt = lines_txt.gsub(/^(\W*)9(\W+)Sole/im, "9. Sole")
      lines_txt = lines_txt.gsub(/^(\W*)10(\W+)Share/im, "10. Share")
      lines_txt = lines_txt.gsub(/^(\W*)11(\W+)Aggregate/im, "11. Aggregate")
      lines_txt = lines_txt.gsub(/^(\W*)12(\W+)Check/im, "12. Check")
      lines_txt = lines_txt.gsub(/^(\W*)13(\W+)Percent/im, "13. Percent")
      lines_txt = lines_txt.gsub(/^(\W*)14(\W+)Type/im, "14. Type")
    else # Convert G into D
      lines_txt = lines_txt.gsub(/^(\W*)4(\W+)Citizen/im, "4. Citizen")
      lines_txt = lines_txt.gsub(/^(\W*)5(\W+)Sole/im, "5. Sole")
      lines_txt = lines_txt.gsub(/^(\W*)6(\W+)Share/im, "6. Share")
      lines_txt = lines_txt.gsub(/^(\W*)7(\W+)Sole/im, "7. Sole")
      lines_txt = lines_txt.gsub(/^(\W*)8(\W+)Share/im, "8. Share")
      lines_txt = lines_txt.gsub(/^(\W*)9(\W+)Aggregate/im, "9. Aggregate")
      lines_txt = lines_txt.gsub(/^(\W*)10(\W+)Check/im, "10. Check")
      lines_txt = lines_txt.gsub(/^(\W*)11(\W+)Percent/im, "11. Percent")
      lines_txt = lines_txt.gsub(/^(\W*)12(\W+)Type/im, "12. Type")
      lines_txt = lines_txt.gsub(/^4. Citizen/, "6. Citizen")
      lines_txt = lines_txt.gsub(/^8. Share/, "10. Share")
      lines_txt = lines_txt.gsub(/^7. Sole/, "9. Sole")
      lines_txt = lines_txt.gsub(/^6. Share/, "8. Share")
      lines_txt = lines_txt.gsub(/^5. Sole/, "7. Sole")
      lines_txt = lines_txt.gsub(/^9. Aggregate/, "11. Aggregate")
      lines_txt = lines_txt.gsub(/^10. Check/, "12. Check")
      lines_txt = lines_txt.gsub(/^11. Percent/, "13. Percent")
      lines_txt = lines_txt.gsub(/^12. Type/, "14. Type")
    end

    unless lines_txt.match(/1\. Name/) && lines_txt.match(/11\. Aggregate/) && lines_txt.match(/13\. Percent/)
      if debug_mode
        crap_out("NO OWNERSHIP TABLES (1. name, 11. aggregate, 13. percent)", "lines_txt: #{lines_txt}")
      else
        self.status = -2
        self.save
        return nil
      end
    end

    lines_arr = lines_txt.split(/\n/)


    divider = "------------------------------------------------------------------------------------\n"

    in_form = false
    in_header = true
    filtered = ""
    header_txt = ""
    form_started = false
    form_ended = false
    (0..lines_arr.length - 1).each do |i|
      line = lines_arr[i]

      # See if we're at the beginning of a form. Sometimes it starts w/ item one, sometimes w/ cusip no
      if line.match(/^1\. Name/i)
        in_form = true
      elsif line.match(/^cusip no/i)
        in_form = true
      end
      form_started = form_started || true

      if in_form
        next if line.blank? || line.match(/^\W$/)
        filtered += line + "\n"
      end

      if in_header
        header_txt += line + "\n"
      end

      if line.match(/Date(s*)\s*of\s*Event/i)
        in_header = false
      end

      # See if we're on the last item.
      if in_form && line.match(/^14. Type/i)
        if lines_arr[i + 1]
          val = lines_arr[i + 1].gsub(/\W/, "")
          filtered += val if val.match(/^BD|BK|IC|IV|IA|EP|HC|SA|CP|CO|PN|IN|OO$/)
        end

        if lines_arr[i + 2]
          val = lines_arr[i + 2].gsub(/\W/, "")
          filtered += val if val.match(/^BD|BK|IC|IV|IA|EP|HC|SA|CP|CO|PN|IN|OO$/)
        end

        filtered += divider
        in_form = false
        form_ended = true
      end
    end

    ##############
    #
    # Step 2.1: Get security title, cusip and date
    #
    ##############

    cur_field = nil
    security_title = security_cusip = nil
    header_arr = header_txt.split(/\)/)

    if in_header == false
      header = {}
      header_arr.each do |line|
        if line.match(/\s+\(title/mi)
          header[:security_title] = Db.strip_label_header("title", line)
        end
        if line.match(/\s+\(cusip/mi)
          header[:security_cusip] = Db.strip_label_header("cusip", line)
        end
      end
    else
      header = {}
      header[:security_title] = "unknown"
      header[:security_cusip] = "unknown"
    end
    header[:security_title] = Db.fix_security_title(header[:security_title])

    unless form_started && form_ended
      if debug_mode
        crap_out("NO TABLES IN FORM (Name of reporting person / type of reporting person)", "sta: #{form_started}, end: #{form_ended}, lines: #{JSON.pretty_generate(lines_arr)}") 
      else
        self.status = -7
        self.save
        return nil
      end
    end

    ##############
    #
    # Step 3, separate into fields: owner[1] => "company name", etc
    #
    ##############
    label_starts = [ "1. Name", "2. Check", "3. SEC", "4. Source", "5. Check", "6. Citizen", "7. Sole", "8. Share", "9. Sole", "10. Share", "11. Aggregate", "12. Check", "13. Percent", "14. Type" ]

    arr_fields = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14"]
    arr_filter_out = [2, 3, 5, 12]

    debug_tables = ""
    owners_hsh = []
    filtered_owners = filtered.split(/#{divider}/)
    (0..filtered_owners.length - 1).each do |i|
      txt = filtered_owners[i]

      # Skip weirdo tables that look like forms at the end of the doc
      if type == "D"
        has_source = txt.match(/source(s*) of fund/i)
      else
        has_source = true
      end
      has_voter = txt.match(/sole vot/i) || txt.match(/sole power/i)
      has_aggregate = txt.match(/aggregate amount/i)
      has_percent = txt.match(/percent of\s+(class|series)/i)
      unless has_source && has_voter && has_aggregate && has_percent
        #crap_out "NO STUFFZ", "has_source: #{has_source}, has_voter: #{has_voter}, has_aggregate: #{has_aggregate}, has_percent: #{has_percent}, txt: #{txt}\n\n\nfiltered: #{filtered}"
        debug_tables += "==== Skipping table ##{i} within form: #{self.id}, has_source: #{has_source}, has_voter: #{has_voter}, has_aggregate: #{has_aggregate}, has_percent: #{has_percent}, txt: #{txt}\n\n\nfiltered: #{filtered}.\n"
        next
      end

      in_field = nil
      lines = txt.split(/\n/)

      owner = {}
      (1..14).each do |num|
        owner[num] = "" # unless arr_filter_out.include? num
      end
      max_length_number = 6

      num = -1
      lines.each do |line|
        is_label = false
        label_starts.each do |lbl|
          if line.match(/^#{lbl}/) # It's a label
            is_label = true
            matches = line.match(/(\d+)\. (.+)/)
            #next if arr_filter_out.include? matches[1].to_i

            if matches.nil?
              self.status = -17
              self.save
              return nil
            end

            num = matches[1].to_i
            val = matches[2]
            val = Db.strip_label(num, val)
            owner[num] += " " + val unless val.blank?
          end
        end
        next if is_label || num == -1
        owner[num] += " " + Db.strip_label(num, line)
      end
      owners_hsh << owner
    end

    if owners_hsh.length == 0
      if debug_mode
        crap_out "NO OWNERS IN FILTERED", "debug_tables: #{debug_tables}"
      else
        self.status = -3
        self.save
        return nil
      end

    end

    ##############
    #
    # Step 4, populate owner objects, extract # of shares and % owned
    #
    ##############
    security_shares = nil
    percent_of_class = nil
    owners = []
    num_group_members = 0
    owners_hsh.each do |hsh|
      owner = {}

      owner[:name] = hsh[1]
      owner[:source_of_funds] = hsh[4]
      owner[:citizenship] = hsh[6]
      owner[:sole_voting_power] = hsh[7].gsub(/\D/, "")
      owner[:shared_voting_power] = hsh[8].gsub(/\D/, "")
      owner[:sole_dispositive_power] = hsh[9].gsub(/\D/, "")
      owner[:shared_dispositive_power] = hsh[10].gsub(/\D/, "")
      owner[:aggregate_amt] = hsh[11].gsub(/\D/, "")
      security_shares = owner[:aggregate_amt] if security_shares.blank?
      owner[:percent_of_class] = hsh[13]
      percent_of_class = owner[:percent_of_class] if percent_of_class.blank?
      owner[:type_of_reporting_person] = hsh[14]

      owner[:is_group_member] = 0

      if security_shares.blank? && !owner[:sole_voting_power].blank?
        security_shares = owner[:sole_voting_power]
      end

      owners << owner
    end

    security_shares = security_shares.split(/\s+/)[0]
    if security_shares.blank?
      self.status = -15
      self.save
      puts "== blank security_shares, status -15 "
      return nil
    end
    security_shares = security_shares.gsub(/\D/, "")
    if security_shares.to_i > 2147483646
      security_shares = -1
    end

    # Group owners by # of shares and/or percentage owned. Each becomes a record in MajorOwners
    owner_groups = []
    (0..100).each do |i|
      owner_groups[i] = []
    end

    group_cur = 0
    if sec_header[:group_members] && sec_header[:group_members].length > 0
      owners = owners.sort_by { |hsh| hsh[:aggregate_amt].to_i }
      (0..owners.length - 1).each do |i|
        owner = owners[i]
        if i > 0
          if owner[:aggregate_amt] == owners[i - 1][:aggregate_amt] || owner[:percent_of_class] == owners[i - 1][:percent_of_class]
            owners[i - 1][:is_group_member] = group_cur
            owner[:is_group_member] = group_cur
          else
            group_cur += 1
          end
        end
      end

      owners.each do |owner|
        owner_groups[owner[:is_group_member]].push(owner)
      end
    else
      group_cur = 0
      owner_groups[0] = owners
    end

    owner_groups = owner_groups.slice(0, group_cur + 1)

    if security_shares.blank? || percent_of_class.blank?
      if debug_mode
        crap_out "NO OWNERS? (sec shares, % blank)", "debug_tables: #{debug_tables}, security_shares: [#{security_shares}], percent_of_class: [#{percent_of_class}], \nowners: #{JSON.pretty_generate(owners)}, \ntext: #{JSON.pretty_generate(lines_arr)}"
      else
        self.status = -4
        self.save
        return nil
      end
    end

    header.merge!({
        :security_shares => security_shares,
        :percent_of_class => percent_of_class
    })

    header = sec_header.merge(header)
    record = {
      :header => header,
      :owner_groups => owner_groups
    }
    return record
  end

end
