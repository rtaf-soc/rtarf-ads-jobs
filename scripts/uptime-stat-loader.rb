#!/usr/bin/env ruby

require 'json'
require 'pg'
require 'time'
require 'net/http'
require 'uri'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true


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

def escape_char(str)
  return "#{str}".tr("'", "")
end

def upsertData(dbConn, obj, seq)
  name = obj['name']
  pctUptime = obj['pctUptime']
  successCnt = obj['successCnt']
  totalCnt = obj['totalCnt']

  orgId = "default"
  
  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"Monitoring\" 
        (
            monitoring_id,
            name,
            check_date,
            org_id,
            uptime_pct,
            success_check_count,
            total_check_count,
            created_date
        )
        VALUES
        (
            gen_random_uuid(),
            '#{escape_char(name)}',
            CURRENT_TIMESTAMP,
            '#{escape_char(orgId)}',
            #{pctUptime},
            #{successCnt},
            #{totalCnt},
            CURRENT_TIMESTAMP
        )
        ON CONFLICT(name)
        DO UPDATE SET 
          check_date = CURRENT_TIMESTAMP,
          uptime_pct = #{pctUptime},
          success_check_count = #{successCnt},
          total_check_count = #{totalCnt}
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

def getMonitoringRecords(conn, monitorings)

  seq = 0
  monitorings.each do |monitoring|
    name = monitoring['name']
    group = monitoring['group']
    key = monitoring['key']
    results = monitoring['results']

    seq = seq + 1

    totalCnt = 0
    successCnt = 0

    results.each do |result|
      isSuccess = result['success']
      totalCnt = totalCnt + 1
      if (isSuccess)
        successCnt = successCnt + 1
      end
    end

    pctUptime = ((successCnt / totalCnt) * 100).to_i

    puts("DEBUG - Calculated uptime for [#{name}], Success=[#{successCnt}] from [#{totalCnt}], uptime=[#{pctUptime}]")
    
    obj = Hash.new

    obj['name'] = name
    obj['pctUptime'] = pctUptime
    obj['successCnt'] = successCnt
    obj['totalCnt'] = totalCnt

    upsertData(conn, obj, seq)
  end
end

domain = ENV["UPTIME_ENDPOINT"]
endPoint = "#{domain}/api/v1/endpoints/statuses"
url = URI.parse(endPoint)

puts("DEBUG - Calling endpoint [#{endPoint}...]")
jsonData = ""

begin
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = (url.scheme == "https")

  request = Net::HTTP::Get.new(url.request_uri)
  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    jsonData = JSON.parse(response.body)
  else
    puts("ERROR - http status is [#{response.code}] [#{response.message}]")
    exit(1)
  end
rescue => e
  puts("ERROR - [#{e.message}]")
  exit(2)
end

pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")
getMonitoringRecords(conn, jsonData)
