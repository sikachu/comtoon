require 'bundler/setup'
require 'net/http'
require 'nokogiri'
require 'time'
require './db_connection'

THAI_MONTHS = [nil] + %w(มกราคม กุมภาพันธ์ มีนาคม เมษายน พฤษภาคม มิถุนายน กรกฎาคม สิงหาคม กันยายน ตุลาคม พฤศจิกายน ธันวาคม)
HOST = URI 'http://www.comtoon.com'
COOKIE_INIT_PATH = '/v3/releaseChk.asp'
GATEKEEPER_PATH = '/v3/release.asp'
RELEASE_DATA_PATH = '/database/w/hl/ct_index.asp'

def http
  @http ||= Net::HTTP.new(HOST.hostname, HOST.port)
end

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

data.each_pair do |date, release|
  releases.update({ date: date }, { date: date, release: release }, upsert: true)
  releases.ensure_index [['date', Mongo::DESCENDING]], unique: true
end
