# encoding: UTF-8

#require 'action_view'
include ActionView::Helpers::DateHelper

class Db

#  require 'date_helper'

  def self.mysql_escape(str)
    ActiveRecord::Base.connection.quote(str)
  end


  def self.log_time(start, str)
    from_time = Time.now

    txt = distance_of_time_in_words(start, Time.now) + " --- " + (Time.now - start).to_s + " --- #{str}\n"
    puts txt
    Rails.logger.warn(txt)
  end

  def self.make_name_searchable(query)
    query = query.gsub(/\b(The|Company|Inc|Llc|LLC|Corp)\b/i, "")
    query = query.gsub(/\b(st)\b/i, "street")
    query = query.gsub(/\b(assoc)\b/i, "associates")
    #query = query.gsub(/-|\.|,|;|-|'/, " ")
    query = query.gsub(/\W+/, " ")
    query = Db.trim(query.downcase)
    return query
  end



  def self.get_field(sql)
    str = nil
    results = ActiveRecord::Base.connection.execute(sql)
    results.each do |res|
      str = res[0]
    end
    return str
  end

  def self.get_fields(sql)
    str = nil
    results = ActiveRecord::Base.connection.execute(sql)
    if results.count > 1
      abort "Mult results"
    end
    results.each do |res|
      return res
    end
  end

  def self.get_rows(sql)
    str = nil
    results = ActiveRecord::Base.connection.select_all(sql)
    return results
  end

  def self.get_row(sql)
    str = nil
    results = ActiveRecord::Base.connection.select_all(sql)
    if results.length != 1
      return nil
    end
    return results[0]
  end

  def self.exec_sql(sql)
    results = ActiveRecord::Base.connection.execute(sql)
  end

  def self.cik_to_symbol(cik)
    cur = DirectOwner.where(issuer_cik: cik).first
    return cur.issuer_symbol || "n/a" if cur
    return nil
  end

  def self.cik_to_cw_id(cik)
    sql = "
      SELECT distinct(cw_id)
      FROM cik_name_lookup
      WHERE cik = '#{cik}'
    "
    return get_field(sql)
  end

  def self.fix_security_title(security_title)
    return "" if security_title.nil?
    if security_title.match(/Common/i) && !security_title.match(/Class|Series/i)
      security_title = "Common Stock"
    end
    if security_title.match(/Ordinary/i) && !security_title.match(/Class|Series/i)
      security_title = "Ordinary Shares"
    end
    security_title.gsub!(/-+/, '-') # Strip out lines
    security_title = security_title.slice(0, 64)
    return security_title
  end

  def self.strip_label(num, val)

    # Remove random lines
    val = remove_lines(val)

    case num
    when 1
      val = val.gsub(/name(.+?)person(s*)\W*/mi, "")

      val = val.gsub(/S\.S\.(.+?)\)\W*/i, "")
      val = val.gsub(/I\.R\.S\.(.+?)\)\W*/i, "")
      val = val.gsub(/IRS(.+?)ONLY\s*\)\W*/mi, "")
      val = val.gsub(/I\.R\.S(.+?)ONLY\s*\)\W*/mi, "")

      val = val.gsub(/I\.R\.S\.(.+?)person\W*/mi, "")
      val = val.gsub(/I\.R\.S\.(.+?)No\W*/mi, "")
      val = val.gsub(/S\.S\.(.+?)PERSON(s*)\W*/mi, "")

      val = val.gsub(/S\.S\. OR\W*/mi, "")
      val = val.gsub(/\d\d-\d\d\d\d\d\d\d/mi, "")

      val = val.gsub(/\.+/, '.')
      val = val.gsub(/-+/, '-')
      val = val.gsub(/_+/, '_')
    when 4
      val = val.gsub(/source(.+?)fund(.+?)Instructions\W*/i, "")
      val = val.gsub(/source(.+?)fund(s*)\W*/i, "")
    when 6
      val = val.gsub(/citizen(.+?)tion(s*)\W*/i, "")
    when 7
      val = val.gsub(/sole(.+?)power(s*)\W*/i, "")
    when 8
      val = val.gsub(/shared(.+?)power(s*)\W*/i, "")
    when 9
      val = val.gsub(/sole(.+?)power(s*)\W*/i, "")
    when 10
      val = val.gsub(/shared(.+?)power(s*)\W*/i, "")
    when 11
      val = val.gsub(/aggreg(.+?)person(s*)\W*/i, "")
    when 13
      val = val.gsub(/percent(.+?)\(9\W*/i, "")
      val = val.gsub(/percent(.+?)\s+9\W*/i, "")
      val = val.gsub(/percent(.+?)\(11\)\W*/i, "")
      val = val.gsub(/percent(.+?)row(s*)\W*/i, "")
    when 14
      val = val.gsub(/type(.+?)person(.+?)ctions\)\W*/i, "")
      val = val.gsub(/type(.+?)person(s*)\W*/i, "")
    end

    return val
  end

  def self.remove_lines(str)
    str = str.gsub(/-+/, '-')
    str = str.gsub(/_+/, '_')
    return str
  end

  def self.strip_label_header(type, val)
    val = remove_lines(val)

    case type
    when "title"
      val = val.gsub(/\(title(.+?)security/mi, "")
      val = val.gsub(/\(title(.+?)securities/mi, "")
    when "cusip"
      val = val.gsub(/\(cusip\s+number/mi, "")
    when "date"
      val = val.gsub(/\(date(.+?)statement(s*)/mi, "")
    end

    return self.trim(val)
  end

  def self.is_line_number?(line)
    return !(self.trim(line).gsub(/\W/, "").match(/^\d+$/)).nil?
  end

  def self.txt_to_lines(txt)
    # Pre-processing and removing of noise
    # Fixes for annoying special cases
    txt = txt.gsub(/­/, "")  # strip 'soft-hyphen'
    txt = txt.gsub(/&#173;/, "") # soft-hyphen
    txt = txt.gsub(/&#160;/, " ") # space

    txt = txt.gsub('<IMS-DOCUMENT>', "<SEC-DOCUMENT>")
    txt = txt.gsub('</IMS-DOCUMENT>', "</SEC-DOCUMENT>")
    txt = txt.gsub('<IMS-HEADER>', "<SEC-HEADER>")
    txt = txt.gsub('</IMS-HEADER>', "</SEC-HEADER>")

    if txt.match(/<htm1>/)  # all the ls are 1s in some forms for some reason
      return nil
    end

    if !txt.match(/<html.*?>(.*)<\/html>/mi)  # Text form
      html = txt.match(/<SEC-DOCUMENT.*?>(.*)<\/SEC-DOCUMENT>/mi)
      if html.nil?
        puts "=== Invalid <SEC-DOCUMENT> tag, skipping"
        return nil
      end
      html = html[1]

      html.gsub!(/<SEC-HEADER>(.+)<\/SEC-HEADER>/im, "")  # Some forms have enormous PDF documents embedded, skip these since they can't be parsed and we only really care about the metadata

      lines_raw = html.split(/\n/)
      html = ""
      (0..lines_raw.length - 1).each do |x|
        str = self.trim(self.fix_newlines_whitespace(lines_raw[x]))
        unless str.blank?
          html += str + "\n"
        end
      end
    else  # HTML form
      html = "<html>" + txt.match(/<html.*?>(.*)<\/html>/mi)[1] + "</html>"
      html = html.gsub(/Reporting(\s+)Person/mi, "Reporting Person")

      doc = Nokogiri::HTML(html, nil, 'UTF-8')

      html = self.clean_doc(doc)

#abort html
    end

    return html
  end
  
  def self.clean_doc(doc)
    html = ""
    doc.children.each do |node|
      if node.is_a? Nokogiri::XML::Element
        html += self.clean_node(node)
      end
    end

    return  html
  end

  def self.clean_node(node)
    if node.children.length == 0
      txt = self.trim(self.fix_newlines_whitespace(node.text))
      if txt.blank?
        return ""
      else
        return txt + "\n"
      end
    end

    html = ""
    node.children.each do |node|
      html += self.clean_node(node)
    end
    return html
  end


  def self.filter_labels(line)
    line = line.gsub(/NAME(.*) OF REPORTING PERSON(S*)(\W*)/i, "")
    line = line.gsub(/(I.R.S.|IRS) IDENTIFICATION(.+)ABOVE PERSON(S*)(\W*)/i, "")
    line = line.gsub(/check the appropriate(.+?)see instructions(\W*)/i, "")
    line = line.gsub(/check the appropriate(.+?)of a group(\W*)/i, "")

    line = line.gsub(/SOURCE OF FUNDS(\W*)/i, "")
    line = line.gsub(/CITIZENSHIP OR PLACE OF ORGANIZATION(\W*)/i, "")
    line = line.gsub(/SOLE VOTING POWER(\W*)/i, "")
    line = line.gsub(/SHARED VOTING POWER(\W*)/i, "")
    line = line.gsub(/SOLE DISPOSITIVE POWER(\W*)/i, "")
    line = line.gsub(/SHARED DISPOSITIVE POWER(\W*)/i, "")
    line = line.gsub(/AGGREGATE AMOUNT BENEFICIALLY OWNED BY EACH REPORTING PERSON(\W*)/i, "")
    line = line.gsub(/PERCENT OF CLASS REPRESENTED BY AMOUNT IN ROW \(11\)(\W*)/i, "")
    line = line.gsub(/TYPE OF REPORTING PERSON(\W*)/i, "")
  end


  def replaceWordChars(s)
    s = s.gsub(/[\u2018|\u2019|\u201a]/, "\'");
    s = s.gsub(/[\u201c|\u201d|\u201e]/, "\"");
    s = s.gsub(/\u2026/, "...");
    s = s.gsub(/[\u2013|\u2014]/, "-");
    s = s.gsub(/\u02c6/, "^");
    s = s.gsub(/\u2039/, "<");
    s = s.gsub(/\u203a/, ">");
    s = s.gsub(/[\u02dc|\u00a0]/, " ");
    
    return s;
  end

  def self.clean(str)
    str = str.gsub(/\r\n\s+/, "")
    str = str.gsub(/\s+/, " ")
    #str = str.strip
    #str = str.gsub("\u00a0", "-").gsub("\u2013", "-").gsub("\u2014", "-").gsub("\u2018", "'").gsub("\u2019", "'").gsub("\u201c", '"').gsub("\u201d", '"')
    #str = replaceWordChars(str)
    #str = str.to_my_utf8
    return str
  end

  # Json implementation's 'clean' function changes non-ascii characters to \u####. This reverts them back to utf-8 chars
  def self.fix_json(str)
    return str.gsub(/\\u([0-9a-z]{4})/) {|s| [$1.to_i(16)].pack("U")}
  end

  def self.friendly_filename(filename)
      filename.gsub(/[^\w\s_-]+/, '')
              .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
              .gsub(/\s+/, '_')
  end

  def self.clean2(str)
    str = str.gsub(/\r|\n/, "")
    str = str.gsub(/\s+$/, "")
    return str
  end

  def self.trim(str)
    str = str.gsub(/\s+$/, "")
    str = str.gsub(/^\s+/, "")
    return str
  end

  def self.fix_newlines_whitespace(str)
    return "" if str.nil?
    str.gsub!(/\n/, " ")
    str.gsub!(/\s+/, " ")
    str.gsub!(/ /, " ")  # String utf-8 char, A0
    return str
  end

  def self.clean_company(str)
    arr = str.split(/\s\s+/)
    if arr.length == 1
      return self.clean2(str)
    end
    if arr.length == 2
      return self.clean2(arr[0])
    end
    abort("Invalid company name: #{str}")
  end

  def self.clean_xml(str)
    str = str.gsub(/&/, "&amp;").gsub(/&amp;amp;/, "&amp;")
  end


end
