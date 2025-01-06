#!/usr/bin/env ruby

require 'json'
require "base64"
require 'net/http'
require './utils'
require 'redis'
require 'pg'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true

def load_log_aggregate(redisObj, aggrType)
  puts("DEBUG : Start loading log aggregate [#{aggrType}] from Redis...\n")

  cnt = 0
  redisObj.scan_each(match: "#{aggrType}:*") do |key|
      aggrCount = redisObj.get(key)

      type, keyword = key.split(":")

      cnt = cnt + 1
      puts("DEBUG : Loading [#{type}] [#{keyword}] [#{aggrCount}]\n")
  end

  puts("DEBUG : Done loading [#{cnt}] records from Redis\n")
  return cnt
end

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

###### Main #####

puts("INFO - Starting program to load log aggregated data to PostgreSQL...")
mode = ENV['MODE']

##### Main #####
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

aggrTypeNetwork = ENV['AGGR_TYPE_NETWORK']

conn = connect_db(ENV["PG_HOST"], ENV["PG_DB"], ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL [#{ENV["PG_HOST"]}] [#{ENV["PG_DB"]}]")
  exit 101
end

totalLoad = load_log_aggregate(redis, aggrTypeNetwork)

puts("INFO : ### Done loading [#{totalLoad}] records to PostgreSQL\n")
