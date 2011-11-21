require 'rubygems'
require 'hpricot'
require 'iconv'
require 'time'
require 'builder'
require 'active_support/ordered_hash'
include ActiveSupport

THAI_MONTHS = [nil] + %w(มกราคม กุมภาพันธ์ มีนาคม เมษายน พฤษภาคม มิถุนายน กรกฎาคม สิงหาคม กันยายน ตุลาคม พฤษจิกายน ธันวาคม)

# fetch header and stuff
cookie = `curl -i http://www.comtoon.com/v3/releaseChk.asp`.match(/Set-Cookie: (.+); path=/)[1]

# trigger stupid page
`curl -b #{cookie} http://www.comtoon.com/v3/release.asp`

# and then calling the actual data!
result = `curl -b #{cookie} http://www.comtoon.com/database/w/hl/ct_index.asp`.match(/function showrelease\(\)\{x= "(.+)"; return \(x\);\}/)[1].gsub(/(&nbsp;| )+/, ' ')
doc = Hpricot.parse(Iconv.conv('utf8', 'tis620', result))
date = Time.parse("0:00")
publisher = ""
data = OrderedHash.new

(doc/"tr").each do |tr|
  if tr[:bgcolor] == "#FFFF99"
    # encouter a new date row
    date_match = tr.innerText.match /ที่ ([0-9]{1,2}) (.+) .+ ([0-9]{1,4})/
    date = Time.mktime((date_match[3].to_i - 543), THAI_MONTHS.index(date_match[2]), date_match[1].to_i, 8).xmlschema[0...10]
  elsif tr[:bgcolor] == "#99CCFF"
    # encouter a new publisher row
    publisher = tr.innerText
  else
    # comic row, add a new object to hash!
    data[date] ||= OrderedHash.new
    data[date][publisher] ||= []
    data[date][publisher] += [tr.innerText.strip]
  end
end

# YAML type, deprecated
# data.each do |i| (date, publishers = i)
#   puts ">> #{date}"
#   output = ""
#   publishers.each do |j| (publisher, comics = j)
#     output += "\"#{publisher}\":\n"
#     comics.each do |comic|
#       output += "  - \"#{comic}\"\n"
#     end
#   end
#   puts output
# end

data.each do |i| (date, publishers = i)
  output = ""
  publishers.each do |j| (publisher, comics = j)
    output += "<strong>#{publisher}</strong><ul>"
    comics.each do |comic|
      output += "<li>#{comic}</li>"
    end
    output += "</ul>"
  end
  output += "<p>ที่มา: <a target='_blank' href='http://www.comtoon.com'>Comtoon.com</a></p>"

  # write to file
  File.open("data/#{date}.html", 'w+') {|f| f.write(output) }
end

# generate XML output
xml = Builder::XmlMarkup.new
xml.instruct!
xml.rss :version => "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "Thai comic update"
    xml.link "http://feedproxy.google.com/ThaiComicUpdate"
    xml.description "Daily Thailand's comic release update. However, please note that this feed might be broken anytime. In case that happend, contact me at http://sikachu.com :)"
    xml.generator "RubyXMLBuilder"
    xml.language "th"
    xml.atom :link, :type => "application/rss+xml", :rel => "self", :href => "http://comic.dev.7republic.com/rss.xml"
    
    # load files
    Dir["data/*.html"].sort{|x,y| y <=> x }.each do |filename|
      d = filename.match /([0-9]{4})-([0-9]{2})-([0-9]{2})\.html/
      time = Time.mktime(d[1].to_i, d[2].to_i, d[3].to_i, 1)
      xml.item do
        xml.title "หนังสือการ์ตูนออกใหม่วันที่ #{time.strftime("%d/%m/%Y")}"
        xml.description do
          xml << "<![CDATA[" << File.read(filename) << "]]>"
        end
        xml.guid "comic##{d[1]}-#{d[2]}-#{d[3]}", :isPermaLink => "false"
        xml.pubDate time.utc.rfc822
      end
    end
  end
end

File.open("rss.xml", 'w+') {|f| f.write(xml.target!) }