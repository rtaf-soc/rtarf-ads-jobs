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

def upsertData(dbConn, type, keyword, aggrCount, seq)
  # 20250106_logstash1-aggregator-cache-loader-2_zeek.dns^1.179.227.84^173.245.59.167^dns^udp

  dateStr, aggregatorPod, attributes = keyword.split("_")
  dataSet, srcIp, dstIp, protocol, transport = attributes.split("^")
  srtNetwork = ""
  dstNetwork = ""

  puts("INFO : [#{seq}] [#{dateStr}] [#{aggregatorPod}] [#{dataSet}] [#{srcIp}] [#{dstIp}] [#{protocol}] [#{transport}]")
end

def load_log_aggregate(dbConn, redisObj, aggrType)
  puts("DEBUG : Start loading log aggregate [#{aggrType}] from Redis...\n")

  cnt = 0
  redisObj.scan_each(match: "#{aggrType}:*") do |key|
      aggrCount = redisObj.get(key)

      type, keyword = key.split(":")

      cnt = cnt + 1
      puts("DEBUG : [#{cnt}] Loading [#{type}] [#{keyword}] [#{aggrCount}]\n")

      upsertData(dbConn, type, keyword, aggrCount, cnt)
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

pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connect to PostgreSQL [#{pgHost}] [#{pgDb}]")
totalLoad = load_log_aggregate(conn, redis, aggrTypeNetwork)

puts("INFO : ### Done loading [#{totalLoad}] records to PostgreSQL\n")
