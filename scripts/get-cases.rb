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

def invoke_api(orgId, apiName, endpoint, method, bodyObj)
  uri = "#{endpoint}/#{apiName}"
  puts("INFO : Using URI [#{uri}]\n")

  uriObj = URI.parse(uri)
  https = Net::HTTP.new(uriObj.host, uriObj.port)

  useSSL = true
  if m = endpoint.match(/^http:\/\/(.+?)$/)
    useSSL = false
  end

  https.use_ssl = useSSL
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  https.read_timeout = 10
  https.open_timeout = 1
  https.max_retries = 0

  jsonStr = ''

  request = Net::HTTP::Get.new(uriObj.path)
  if (method == 'POST')
    request = Net::HTTP::Post.new(uriObj.path)
    jsonStr = '{}'
  end

  if (!bodyObj.nil?)
    # Convert to JSON
    jsonStr = bodyObj.to_json
  puts(jsonStr)
  end

  request['Accept'] = 'application/json'
  request['Content-Type'] = 'application/json'
  #request['Authorization'] = api_key
  request['X-Organisation'] = orgId
  request.basic_auth(ENV["THEHIVE_USER"], ENV["THEHIVE_PASSWORD"])

  request.body = jsonStr

  status = ""
  begin
    response = https.request(request)
    status = response.code
    responseStr = response.body
  end

  return status, responseStr
end

puts("INFO - Starting program to load TheHive cases...")

apiName = 'api/v1/query'
data = {
  "query" => [
    {"_name" => "listCase"},
    {"_name" => "page", "from" => 0, "to" => 10},
    #{"_name" => "sort", "_fields" => [{"_updatedAt" => "asc"}]},

    {"_name" => "filter", "_eq" => {"_field" => "number", "_value" => "1"}},

    #{
    #  "_name" => "filter", 
    #  "_and" => [
    #    {"_gte" => {"_field" => "_createdAt", "_value" => "173366282500"}}
    #  ],
    #}
  ],

  "excludeFields" => ["description", "summary"],
}

status, responseStr = invoke_api('astro', apiName, ENV["THEHIVE_ENDPOINT"], 'POST', data)

if (status != '200')
  puts("ERROR : Calling API [#{apiName}] error with status [#{status}]!!!\n")
  puts(responseStr)
  exit 100 
end

puts(responseStr)
