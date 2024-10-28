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

puts("INFO - Starting program to load system variables data to cache...")
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

orgId = ENV["ORG_ID"]
getListApiName = 'GetSystemVariables'
getCountApiName = 'GetSystemVariableCount'

getListApiObj = Hash.new()
getListApiObj['method'] = 'POST'
getListApiObj['controller'] = 'SystemVariable'
getListApiObj['path'] = '/'
getListApiObj['body'] = 'SystemVariableQuery'

getCountApiObj = Hash.new()
getCountApiObj['method'] = 'POST'
getCountApiObj['controller'] = 'SystemVariable'
getCountApiObj['path'] = '/'
getCountApiObj['body'] = 'SystemVariableQuery'

dataObj = Hash.new()
dataObj['SystemVariableQuery'] = Hash.new()

dataObj['SystemVariableQuery']['FullTextSearch'] = ''
dataObj['SystemVariableQuery']['VariableName'] = ''

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
objectCount = responseStr.to_i
puts("INFO : Got total [#{objectCount}] records of IOC host\n")

pageCount = objectCount / recordPerPage
if ((objectCount % recordPerPage) > 0)
  pageCount = pageCount + 1
end

totalLoad = 0

for page in 1..pageCount do
  offset = ((page-1) * recordPerPage) + 1
  puts("INFO : ### Loading page [#{page}] from [#{pageCount}], offset=[#{offset}]...\n")

  dataObj['SystemVariableQuery']['Offset'] = offset
  dataObj['SystemVariableQuery']['Limit'] = recordPerPage

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
    code = item['variableName']

    key = "#{orgId}:system-variable:#{code}"
    value = item.to_json

    puts("INFO : ### Loading variable [#{key}] --> [#{value}] to cache...\n")
    if (mode != 'local')
      load_cache(redis, key, value, ENV["CACHE_TTL_SEC"].to_i)
    end

    totalLoad = totalLoad + 1
  end
end

puts("INFO : ### Done loading [#{totalLoad}] records to cache\n")
