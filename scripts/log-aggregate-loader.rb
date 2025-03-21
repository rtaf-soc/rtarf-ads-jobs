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

  dataSet = ''
  srcNetwork = '' 
  dstNetwork = '' 
  protocol = '' 
  transport = ''
  mispTlp = ''
  mitrPattern = ''
  srcIp = ''
  dstIp = ''

  if (type == 'aggr_network_v3')
    dataSet, srcNetwork, dstNetwork, protocol, transport = attributes.split("^")
  elsif (type == 'aggr_network_mitr_dst_ip_v1')
      dataSet, srcNetwork, dstNetwork, protocol, transport, mispTlp, mitrPattern = attributes.split("^")
  elsif (type == 'aggr_network_mitr_src_ip_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, mispTlp, mitrPattern = attributes.split("^")
  elsif (type == 'aggr_network_misp_dst_ip_tlp_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, mispTlp = attributes.split("^")
  elsif (type == 'aggr_network_misp_src_ip_tlp_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, mispTlp = attributes.split("^")
  elsif (type == 'aggr_network_blacklist_dest_ip_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, srcIp, dstIp = attributes.split("^")
  elsif (type == 'aggr_network_blacklist_src_ip_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, srcIp, dstIp = attributes.split("^")
  elsif (type == 'aggr_crowdstrike_incident_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, 
    csEventName, csIncidentType, csComputerName, csUserName, csDetectName, csFileName, csIocType, csLocalIp = attributes.split("^")
  end

  loaderName = "log-aggregate-loader.rb"
  orgId = "default"

  puts("INFO : [#{seq}] [#{type}] [#{dateStr}] [#{aggregatorPod}] [#{attributes}] --> [#{aggrCount}]")
  
  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"LogAggregates\" 
        (
            log_aggregate_id,
            event_date,
            org_id,
            cache_key,
            data_set,
            aggregator_name,
            loader_name,
            source_ip,
            source_network,
            destination_ip,
            destination_network,
            protocol,
            transport,
            mitr_attack_pattern,
            misp_threat_level,
            evnet_count,
            created_date,
            aggregator_type,
            yyyymmdd,
            cs_event_name,
            cs_incident_type,
            cs_computer_name,
            cs_user_name,
            cs_detect_name,
            cs_file_name,
            cs_ioc_type,
            cs_local_ip
        )
        VALUES
        (
            gen_random_uuid(),
            TO_DATE('#{dateStr}', 'YYYYMMDD'),
            '#{orgId}',
            '#{keyword}',
            '#{dataSet}',
            '#{aggregatorPod}',
            '#{loaderName}',
            '#{srcIp}',
            '#{srcNetwork}',
            '#{dstIp}',
            '#{dstNetwork}',
            '#{protocol}',
            '#{transport}',
            '#{mitrPattern}',
            '#{mispTlp}',
             #{aggrCount},
             current_timestamp,
            '#{type}',
            '#{dateStr}',
            '#{csEventName}',
            '#{csIncidentType}',
            '#{csComputerName}',
            '#{csUserName}',
            '#{csDetectName}',
            '#{csFileName}',
            '#{csIocType}',
            '#{csLocalIp}'
        )
        ON CONFLICT(cache_key)
        DO UPDATE SET evnet_count = #{aggrCount}
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

def load_log_aggregate(dbConn, redisObj, aggrType)
  puts("DEBUG : Start loading log aggregate [#{aggrType}] from Redis...\n")

  cnt = 0
  redisObj.scan_each(match: "#{aggrType}:*") do |key|
      aggrCount = redisObj.get(key)

      type, keyword = key.split(":")

      cnt = cnt + 1
      #puts("DEBUG : [#{cnt}] Loading [#{type}] [#{keyword}] [#{aggrCount}]\n")

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

#aggrTypeNetwork = ENV['AGGR_TYPE_NETWORK']

pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connect to PostgreSQL [#{pgHost}] [#{pgDb}]")

type = 'aggr_network_v3'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_network_mitr_dst_ip_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_network_mitr_src_ip_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_network_misp_dst_ip_tlp_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_network_misp_src_ip_tlp_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_network_blacklist_dest_ip_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_network_blacklist_src_ip_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_crowdstrike_incident_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")
