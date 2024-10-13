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

puts("INFO - Starting program to load blacklist data to cache...")

##### Main #####
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

orgId = ENV["ORG_ID"]
getListApiName = 'GetBlacklists'
getCountApiName = 'GetBlacklistCount'

getListApiObj = Hash.new()
getListApiObj['method'] = 'POST'
getListApiObj['controller'] = 'Blacklist'
getListApiObj['path'] = '/'
getListApiObj['body'] = 'BlacklistQuery'

getCountApiObj = Hash.new()
getCountApiObj['method'] = 'POST'
getCountApiObj['controller'] = 'Blacklist'
getCountApiObj['path'] = '/'
getCountApiObj['body'] = 'BlacklistQuery'

dataObj = Hash.new()
dataObj['BlacklistQuery'] = Hash.new()

dataObj['BlacklistQuery']['BlacklistType'] = nil
dataObj['BlacklistQuery']['BlacklistCode'] = ''
dataObj['BlacklistQuery']['FullTextSearch'] = ''

endpointObj = Hash.new()
endpointObj['uri'] = ENV['API_ENDPOINT']
endpointObj['basicAuthenUserEnvVar'] = 'API_AUTHEN_USER'
endpointObj['basicAuthenPasswordEnvVar'] = 'API_AUTHEN_PASSWORD'


status, responseStr = invoke_api(orgId, getCountApiName, getCountApiObj, endpointObj, dataObj)
if (status != '200')
  puts("ERROR : Calling API [#{getCountApiName}] error with status [#{status}]!!!\n")
  puts(responseStr)

  exit 100 
end

recordPerPage = 100
blackListCount = responseStr.to_i
puts("INFO : Got total [#{blackListCount}] records of blacklist\n")

pageCount = blackListCount / recordPerPage
if ((blackListCount % recordPerPage) > 0)
  pageCount = pageCount + 1
end

totalLoad = 0

for page in 1..pageCount do
  offset = ((page-1) * recordPerPage) + 1
  puts("INFO : ### Loading page [#{page}] from [#{pageCount}], offset=[#{offset}]...\n")

  dataObj['BlacklistQuery']['Offset'] = offset
  dataObj['BlacklistQuery']['Limit'] = recordPerPage

  status, responseStr = invoke_api(orgId, getListApiName, getListApiObj, endpointObj, dataObj)
  if (status != '200')
    puts("ERROR : Calling API [#{getListApiName}] error with status [#{status}]!!!\n")
    puts(responseStr)
  
    exit 100
  end

  dataArr = JSON.parse(responseStr)
  returnedSize = dataArr.count

  puts("INFO : ### Got [#{returnedSize}] records from page [#{page}]\n")

  for item in dataArr
    code = item['blacklistCode']
    type = item['blacklistType']
    blackListJsonStr = item.to_json

    key = "#{orgId}:blacklist:#{type}:#{code}"

    puts("INFO : ### Loading blacklist item [#{key}] to cache...\n")
    #load_cache(redis, key, blackListJsonStr, ENV["CACHE_TTL_SEC"].to_i)

    totalLoad = totalLoad + 1
  end
end

puts("INFO : ### Done loading [#{totalLoad}] records to cache\n")
