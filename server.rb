require 'bundler/setup'
require 'sinatra'
require 'builder'
require './db_connection'

get '/rss.xml' do
  content_type :xml

  # generate XML output
  xml = Builder::XmlMarkup.new
  xml.instruct!
  xml.rss :version => "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
    xml.channel do
      xml.title "Thai comic update"
      xml.link "http://feedproxy.google.com/ThaiComicUpdate"
      xml.description "Daily Thailand's comic release update. However, please note that this feed might be broken anytime. In case that happen, contact me at http://sikachu.com :)"
      xml.generator "RubyXMLBuilder"
      xml.language "th"
      xml.atom :link, :type => "application/rss+xml", :rel => "self", :href => "http://thaicomicupdate.herokuapp.com/rss.xml"

      releases.find({}, sort: [:date, :desc], limit: 20).each do |release|
        body = ""
        release['release'].each_pair do |publisher, comics|
          body += "<strong>#{publisher}</strong><ul>"
          comics.each do |comic|
            body += "<li>#{comic}</li>"
          end
          body += "</ul>"
        end
        body += "<p>ที่มา: <a target='_blank' href='http://www.comtoon.com'>Comtoon.com</a></p>"

        date = Date.parse(release['date'])
        xml.item do
          xml.title "หนังสือการ์ตูนออกใหม่วันที่ #{date.strftime("%d/%m/%Y")}"
          xml.description do
            xml << "<![CDATA[" << body << "]]>"
          end
          xml.guid "comic##{release['date']}", :isPermaLink => "false"
          xml.pubDate date.to_time.rfc822
        end
      end
    end
  end

  xml.target!
end
