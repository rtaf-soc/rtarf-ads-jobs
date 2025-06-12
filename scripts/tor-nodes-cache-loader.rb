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

def loadTorMap(inputFile, cacheKey, mode)
  totalLoad = 0
  orgId = ENV["ORG_ID"]

  File.foreach(inputFile) do |line|
    line.strip!
    next if line.start_with?('#') || line.empty?
    
    fingerPrint, ip, port = line.split(',')
    fingerPrint = fingerPrint.strip
    ip = ip.strip

    key = "#{orgId}:#{cacheKey.strip}:#{ip}"

    puts("[#{key}] => [#{fingerPrint}]")
    if (mode != 'local')
      load_cache(redis, key, fingerPrint, ENV["CACHE_TTL_SEC"].to_i)
    end

    totalLoad = totalLoad + 1
  end

  return totalLoad
end

puts("INFO - Starting program to load TOR nodes map to cache...")
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

totalLoad = loadTorMap('tor-nodes-guard.cfg', 'tor-guard-ip', mode)
puts("INFO : ### Done loading [#{totalLoad}] TOR-guard records to cache\n")

totalLoad = loadTorMap('tor-nodes-exit.cfg', 'tor-exit-ip', mode)
puts("INFO : ### Done loading [#{totalLoad}] TOR-exit records to cache\n")
