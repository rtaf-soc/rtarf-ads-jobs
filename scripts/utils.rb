require 'json'
require "base64"
require 'net/http'
require 'redis'

def load_cache(redisObj, key, value, ttlSec)
  redisObj.setex(key, ttlSec, value)
  testValue = redisObj.get(key)

  if (value != testValue)
    puts("ERROR : Unable to load cache with key [#{key}]\n")
    exit 100
  end
end

def get_api_key(endpointObj)
  userVarName = endpointObj['basicAuthenUserEnvVar']
  passwordVarName = endpointObj['basicAuthenPasswordEnvVar']

  user = ENV[userVarName]
  password = ENV[passwordVarName]

  key = "Basic " + Base64::strict_encode64("#{user}:#{password}")
#puts ("=== [#{user}] [#{password}] [#{key}] ===\n")
  return key
end

def invoke_api(orgId, apiName, apiObj, endpointObj, dataObj)
  endpoint = endpointObj['uri']
  method = apiObj['method']
  path = apiObj['path']
  controller = apiObj['controller']
  bodyName = apiObj['body']
  bodyObj = dataObj[bodyName]

  if (!bodyName.nil? && bodyObj.nil?)
    puts("ERROR : Data object [#{bodyName}] not found in [data] section!!!\n")
    return 
  end

  puts("INFO : Requesting API [#{apiName}] to [#{endpoint}]...\n")
  puts("INFO : Using method [#{method}]\n")

  uri = "#{endpoint}/api/#{controller}/org/#{orgId}/action/#{apiName}#{path}"
  puts("INFO : Using URI [#{uri}]\n")

  uriObj = URI.parse(uri)
  api_key = get_api_key(endpointObj)

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
  elsif (method == 'DELETE')
      request = Net::HTTP::Delete.new(uriObj.path)
  end

  if (!bodyObj.nil?)
    # Convert to JSON
    jsonStr = bodyObj.to_json
  #puts(jsonStr)
  end

  request['Accept'] = 'application/json'
  request['Content-Type'] = 'application/json'
  request['Authorization'] = api_key
  request.body = jsonStr

  status = ""
  begin
    response = https.request(request)
    status = response.code
    responseStr = response.body
  end

  return status, responseStr
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
