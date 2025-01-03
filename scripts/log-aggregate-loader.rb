#!/usr/bin/env ruby

require 'json'
require "base64"
require 'net/http'
require './utils'
require 'redis'

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
      puts("DEBUG : Loading [#{type}] [#{keyword}]\n")
  end

  puts("DEBUG : Done loading [#{cnt}] records from Redis\n")
  return cnt
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
totalLoad = load_log_aggregate(redis, aggrTypeNetwork)

puts("INFO : ### Done loading [#{totalLoad}] records to PostgreSQL\n")
