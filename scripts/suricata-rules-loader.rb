#!/usr/bin/env ruby

require 'json'
require 'pg'
require 'time'

require './utils'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true

def connect_db(host, db, user, password)
  begin
      con = PG.connect(:host => host, 
          :dbname => db, 
          :user => user, 
          :password => password)

  rescue PG::Error => e
      puts("ERROR - Connect to DB [#{e.message}]")
  end

  return con
end

def escape_char(str)
  return "#{str}".tr("'", "")
end

def upsertData(dbConn, incidentObj, seq)
end

############# Main Program #############
puts("INFO - Starting program to load Suricata rules to PostgreSQL...")

mode = ENV['MODE']
pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]
ruleUrl = ENV['RULE_URL']
ruleUser = ENV['RULE_SERVER_USER']
rulePassword = ENV['RULE_SERVER_PASSWORD']

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")

if (mode != 'local')
  begin
    redis = Redis.new(
      :host => ENV["REDIS_HOST"],
      :port => ENV["REDIS_PORT"]
    )

    client_ping = redis.ping
    if (client_ping)
      puts("INFO : Connected to Redis [#{ENV["REDIS_HOST"]}]")
    else
      raise 'Ping failed!!!'
    end
  rescue => e
    puts("ERROR: #{e}")
    exit 100
  end
end

puts("INFO - Downloading rules file from [#{ruleUrl}]...")

arr = []
seq = 0

arr.each do |incident|
  seq = seq + 1

  #json_string = incident.to_json
  #puts json_string
  #upsertData(conn, incident, seq)
end
