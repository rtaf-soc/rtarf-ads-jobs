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

puts("INFO - Starting program to load OUI map to cache...")
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

input_file = "oui-map.cfg"
totalLoad = 0
orgId = ENV["ORG_ID"]

File.foreach(input_file) do |line|
  line.strip!
  next if line.start_with?('#') || line.empty?
  
  mac, hex, vendor = line.split('|')
  key = "#{orgId}:oui-vendor:#{mac}"

  puts("#{key} => #{vendor}")
  if (mode != 'local')
    load_cache(redis, key, vendor, ENV["CACHE_TTL_SEC"].to_i)
  end

  totalLoad = totalLoad + 1
end

puts("INFO : ### Done loading [#{totalLoad}] records to cache\n")
