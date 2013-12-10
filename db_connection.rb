require 'bundler/setup'
require 'mongo'

def db_connection
  unless @db_connection
    db = URI.parse(ENV['MONGOHQ_URL'] || 'mongodb://localhost/comtoon')
    db_name = db.path.gsub(/^\//, '')
    @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
    @db_connection.authenticate(db.user, db.password) unless db.user.nil?
  end
  @db_connection
end

def releases
  db_connection["releases"]
end

