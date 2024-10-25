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

puts("INFO - Starting program to load IOC host data to cache...")
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
getListApiName = 'GetIocHosts'
getCountApiName = 'GetIocHostCount'

getListApiObj = Hash.new()
getListApiObj['method'] = 'POST'
getListApiObj['controller'] = 'IocHost'
getListApiObj['path'] = '/'
getListApiObj['body'] = 'IocHostQuery'

getCountApiObj = Hash.new()
getCountApiObj['method'] = 'POST'
getCountApiObj['controller'] = 'IocHost'
getCountApiObj['path'] = '/'
getCountApiObj['body'] = 'IocHostQuery'

dataObj = Hash.new()
dataObj['IocHostQuery'] = Hash.new()

dataObj['IocHostQuery']['IocEndpoint'] = ''
dataObj['IocHostQuery']['IocType'] = ''

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
ipMapCount = responseStr.to_i
puts("INFO : Got total [#{ipMapCount}] records of blacklist\n")

pageCount = ipMapCount / recordPerPage
if ((ipMapCount % recordPerPage) > 0)
  pageCount = pageCount + 1
end

totalLoad = 0

for page in 1..pageCount do
  offset = ((page-1) * recordPerPage) + 1
  puts("INFO : ### Loading page [#{page}] from [#{pageCount}], offset=[#{offset}]...\n")

  dataObj['IocHostQuery']['Offset'] = offset
  dataObj['IocHostQuery']['Limit'] = recordPerPage

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
    code = item['iocHostCode']
    type = item['iocType']

    key = "#{orgId}:iochost:#{code}"
    value = item.to_json

    puts("INFO : ### Loading IOC host item [#{key}] --> [#{value}] to cache...\n")
    if (mode != 'local')
      load_cache(redis, key, value, ENV["CACHE_TTL_SEC"].to_i)
    end

    totalLoad = totalLoad + 1
  end
end

puts("INFO : ### Done loading [#{totalLoad}] records to cache\n")
