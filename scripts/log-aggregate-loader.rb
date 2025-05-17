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
$csMachineStats = Hash.new()

def upsertMachineStatData(dbConn, obj, seq)
  csComputerName = obj['name']
  aggrCount = obj['lastSeenEventCount']
  orgId = "default"
  
  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"CsMachineStat\" 
        (
            machine_stat_id,
            machine_name,
            last_cs_event_date,
            org_id,
            cs_event_count,
            created_date
        )
        VALUES
        (
            gen_random_uuid(),
            '#{escape_char(csComputerName)}',
            CURRENT_TIMESTAMP,
            '#{escape_char(orgId)}',
            #{aggrCount},
            CURRENT_TIMESTAMP
        )
        ON CONFLICT(machine_name)
        DO UPDATE SET 
          last_cs_event_date = CURRENT_TIMESTAMP,
          cs_event_count = #{aggrCount}
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

def populateMachineStat(csComputerName, aggrCount)
  if ((csComputerName.nil?) || (csComputerName == ""))
    return
  end

  hasFoundName = $csMachineStats.has_key?(csComputerName)
  if (!hasFoundName)
    # Create the new entry
    $csMachineStats[csComputerName] = aggrCount.to_i
  else
    currentSeenCount = $csMachineStats[csComputerName]
    $csMachineStats[csComputerName] = currentSeenCount + aggrCount.to_i
  end
end

def loadMachineStatToDb(conn)
  total = 0
  puts("INFO : ### Updating CS machine stat to DB...\n")

  $csMachineStats.each do |csComputerName, aggrCount|
    total = total + 1

    puts("INFO : ### Updating [#{csComputerName}] count=[#{aggrCount}] to DB...\n")

    obj = Hash.new()
    obj['name'] = csComputerName
    obj['lastSeenEventCount'] = aggrCount
    upsertMachineStatData(conn, obj, total)
  end

  puts("INFO : ### Done Updating [#{total}] CS machine stat to DB\n")
end

def escape_char(str)
  return "#{str}".tr("'", "")
end

def upsertData(dbConn, type, keyword, aggrCount, seq)

  if (keyword.nil?)
    puts("INFO : [keyword] is null in upsertData()\n")
    return
  end

  dateStr, aggregatorPod, attributes = keyword.split("%%")
  if (attributes.nil?)
    puts("INFO : [attributes] is null in upsertData()\n")
    return
  end

  dataSet = ''
  srcNetwork = '' 
  dstNetwork = '' 
  protocol = '' 
  transport = ''
  mispTlp = ''
  mitrPattern = ''
  srcIp = ''
  dstIp = ''
  customField1 = ''
  customField2 = ''
  customField3 = ''
  customField4 = ''
  customField5 = ''
  customField6 = ''
  customField7 = ''
  customField8 = ''
  customField9 = ''
  customField10 = ''
  customField11 = ''
  customField12 = ''
  customField13 = ''
  customField14 = ''
  customField15 = ''

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
    csEventName, csIncidentType, csComputerName, csUserName, csDetectName, csFileName, csIocType, csLocalIp, 
    customField1, customField2, customField3, customField4,
    customField5, customField6, customField7, customField8, customField9 = attributes.split("^")
    #Custom Fields : category,serverityName,tags,eventType, csTechnique,csTactic,csIncidentId,csFineScore,csFineScoreTxt

    populateMachineStat(csComputerName, aggrCount)
  elsif (type == 'aggr_zeek_intel_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, srcIp, dstIp,
    customField1, customField2, customField3, customField4, customField5 = attributes.split("^")
    #intelMatched,intelSeenIndicator,intelSeenType,intelSeenWhere,intelSource
  elsif (type == 'aggr_zeek_suricata_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, srcIp, dstIp,
    customField1, customField2, customField3 = attributes.split("^")
    #suricataPriority,suricataClass,suricataRule
  elsif (type == 'aggr_zeek_weird_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport, srcIp, dstIp,
    customField1, customField2, customField3 = attributes.split("^")
    #weirdRuleName,weirdName,weirdSource
  elsif (type == 'aggr_zeek_dns_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3, customField4 = attributes.split("^") 
    #dnsQuestionName,dnsRegisteredDomain,dnsQueryClassName,dnsQueryTypeName
  elsif (type == 'aggr_zeek_http_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3, customField4, customField5 = attributes.split("^") 
    #requestMethod,urlDomain,userAgent,mimeType,httpStatus
  elsif (type == 'aggr_zeek_radius_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3 = attributes.split("^") 
    #userName,radiusStatus,connectInfo
  elsif (type == 'aggr_zeek_kerberos_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3, customField4 = attributes.split("^") 
    #message,client,service,isSuccess

  elsif (type == 'aggr_zeek_rdp_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3 = attributes.split("^")
    #cookie,result,securityProtocol
  elsif (type == 'aggr_zeek_smb_files_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3 = attributes.split("^")
    #fileName,action,filePath
  elsif (type == 'aggr_zeek_ftp_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2, customField3, customField4 = attributes.split("^")
    #command,replyCode,ftpUser,ftpArgs
  elsif (type == 'aggr_zeek_smtp_v1')
    dataSet, srcNetwork, dstNetwork, protocol, transport,
    customField1, customField2 = attributes.split("^")
    #mailFrom,mailTo
  end

  loaderName = "log-aggregate-loader.rb"
  orgId = "default"

  #puts("INFO : [#{seq}] [#{type}] [#{dateStr}] [#{aggregatorPod}] [#{attributes}] --> [#{aggrCount}]")
  
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
            cs_local_ip,
            custom_field1,
            custom_field2,
            custom_field3,
            custom_field4,
            custom_field5,
            custom_field6,
            custom_field7,
            custom_field8,
            custom_field9,
            custom_field10,
            custom_field11,
            custom_field12,
            custom_field13,
            custom_field14,
            custom_field15
        )
        VALUES
        (
            gen_random_uuid(),
            TO_DATE('#{dateStr}', 'YYYYMMDD'),
            '#{escape_char(orgId)}',
            '#{escape_char(keyword)}',
            '#{escape_char(dataSet)}',
            '#{escape_char(aggregatorPod)}',
            '#{escape_char(loaderName)}',
            '#{escape_char(srcIp)}',
            '#{escape_char(srcNetwork)}',
            '#{escape_char(dstIp)}',
            '#{escape_char(dstNetwork)}',
            '#{escape_char(protocol)}',
            '#{escape_char(transport)}',
            '#{escape_char(mitrPattern)}',
            '#{escape_char(mispTlp)}',
             #{aggrCount},
             current_timestamp,
            '#{escape_char(type)}',
            '#{escape_char(dateStr)}',
            '#{escape_char(csEventName)}',
            '#{escape_char(csIncidentType)}',
            '#{escape_char(csComputerName)}',
            '#{escape_char(csUserName)}',
            '#{escape_char(csDetectName)}',
            '#{escape_char(csFileName)}',
            '#{escape_char(csIocType)}',
            '#{escape_char(csLocalIp)}',
            '#{escape_char(customField1)}',
            '#{escape_char(customField2)}',
            '#{escape_char(customField3)}',
            '#{escape_char(customField4)}',
            '#{escape_char(customField5)}',
            '#{escape_char(customField6)}',
            '#{escape_char(customField7)}',
            '#{escape_char(customField8)}',
            '#{escape_char(customField9)}',
            '#{escape_char(customField10)}',
            '#{escape_char(customField11)}',
            '#{escape_char(customField12)}',
            '#{escape_char(customField13)}',
            '#{escape_char(customField14)}',
            '#{escape_char(customField15)}'
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
  redisObj.scan_each(match: "#{aggrType}!!*") do |key|
      aggrCount = redisObj.get(key)

      type, keyword = key.split("!!")

      cnt = cnt + 1
      puts("DEBUG_00 : [#{cnt}] Loading [#{type}] [#{key}] [#{keyword}] [#{aggrCount}]\n")

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

puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")

type = 'aggr_crowdstrike_incident_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")
# Onlye for aggr_crowdstrike_incident_v1
loadMachineStatToDb(conn)


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


type = 'aggr_zeek_intel_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_suricata_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_weird_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_dns_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_http_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_radius_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_kerberos_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")


type = 'aggr_zeek_rdp_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_smb_files_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_ftp_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")

type = 'aggr_zeek_smtp_v1'
totalLoad = load_log_aggregate(conn, redis, type)
puts("INFO : ### Done loading [#{type}] [#{totalLoad}] records to PostgreSQL\n")
