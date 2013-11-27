require 'bundler/setup'
require 'builder'
require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'time'

THAI_MONTHS = [nil] + %w(มกราคม กุมภาพันธ์ มีนาคม เมษายน พฤษภาคม มิถุนายน กรกฎาคม สิงหาคม กันยายน ตุลาคม พฤษจิกายน ธันวาคม)
HOST = URI 'http://www.comtoon.com'
COOKIE_INIT_PATH = '/v3/releaseChk.asp'
GATEKEEPER_PATH = '/v3/release.asp'
RELEASE_DATA_PATH = '/database/w/hl/ct_index.asp'

http = Net::HTTP.new(HOST.hostname, HOST.port)

# Fetch cookie
response = http.get(COOKIE_INIT_PATH)
cookie = response['Set-Cookie'].split(/;/).first

# trigger gatekeeper page
http.get(GATEKEEPER_PATH, 'Cookie' => cookie)

# and then calling the actual data!
response = http.get(RELEASE_DATA_PATH, 'Cookie' => cookie)
result = response.body.encode('UTF-8', 'TIS-620').match(/function showrelease\(\)\{x= "(.+)"; return \(x\);\}/)[1].gsub(/(&nbsp;| )+/, ' ')

doc = Nokogiri::HTML(result)
date = Time.parse("0:00")
publisher = ""
data = {}

doc.css('tr').each do |tr|
  if tr[:bgcolor] == "#FFFF99"
    # encouter a new date row
    date_match = tr.text.match /ที่ ([0-9]{1,2}) (.+) .+ ([0-9]{1,4})/
    date = Time.mktime((date_match[3].to_i - 543), THAI_MONTHS.index(date_match[2]), date_match[1].to_i, 8).xmlschema[0...10]
  elsif tr[:bgcolor] == "#99CCFF"
    # encouter a new publisher row
    publisher = tr.text
  else
    # comic row, add a new object to hash!
    data[date] ||= {}
    data[date][publisher] ||= []
    data[date][publisher] += [tr.text.strip]
  end
end

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
  FileUtils.mkdir_p('data')
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

File.open("rss.xml", 'w') {|f| f.write(xml.target!) }
