#!/usr/bin/env ruby

require 'json'
require 'watir'
require 'pg'
require 'time'

require './utils'

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

def epochMilliSecToString(epochMilliSec, ifNullSec)
  epoch = epochMilliSec
  if (epoch.nil?)
    epoch = ifNullSec
  end

  second = epoch / 1000.0
  time = Time.at(second)
  dateTimeStr = time.strftime("%Y%m%d %H:%M:%S")

  return dateTimeStr
end

def upsertData(dbConn, incidentObj, seq)

  title = incidentObj['title']
  caseId = incidentObj['caseId']
  pap = incidentObj['pap']
  owner = incidentObj['owner']
  severity = incidentObj['severity']
  summary = incidentObj['summary']
  updatedBy = incidentObj['updatedBy']
  resolutionStatus = incidentObj['resolutionStatus']
  tlp = incidentObj['tlp']
  impactStatus = incidentObj['impactStatus']
  status = incidentObj['status']
  description = incidentObj['description']
  createdAt = incidentObj['createdAt']
  id = incidentObj['id']
  startDate = incidentObj['startDate']
  updatedAt = incidentObj['updatedAt']
  incidentType = incidentObj['_type']
  tags = incidentObj['tags'].join(";")

  orgId = "default"

  createdAtStr = epochMilliSecToString(createdAt, createdAt)
  startDateStr = epochMilliSecToString(startDate, createdAt)
  updateAtStr = epochMilliSecToString(updatedAt, createdAt)

  puts("INFO : [#{caseId}] createdAtMilliSec=[#{createdAt}] [#{createdAtStr}] [#{id}]")
  puts("INFO : [#{caseId}] startDateMilliSec=[#{startDate}] [#{startDateStr}] [#{id}]")
  puts("INFO : [#{caseId}] updatedAtMilliSec=[#{updatedAt}] [#{updateAtStr}] [#{id}]")

  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"Cases\" 
        (
            case_id,
            org_id,
            case_no,
            case_date,
            case_status,
            description,
            incident_type,
            case_owner,
            created_date,

            case_title,
            case_ref_id,
            case_pap,
            case_severity,
            case_summary,
            update_by,
            solution_status,
            case_tlp,
            impact_status,
            start_date,
            update_at,
            tags
        )
        VALUES
        (
            gen_random_uuid(),
            '#{escape_char(orgId)}',
            '#{escape_char(caseId)}',
            TO_DATE('#{createdAtStr}', 'YYYYMMDD HH24:MI:SS'),
            '#{escape_char(status)}',
            '#{escape_char(description)}',
            '#{escape_char(incidentType)}',
            '#{escape_char(owner)}',
            TO_DATE('#{createdAtStr}', 'YYYYMMDD HH24:MI:SS'),

            '#{escape_char(title)}',
            '#{escape_char(id)}',
            '#{escape_char(pap)}',
            '#{escape_char(severity)}',
            '#{escape_char(summary)}',
            '#{escape_char(updatedBy)}',
            '#{escape_char(resolutionStatus)}',
            '#{escape_char(tlp)}',
            '#{escape_char(impactStatus)}',
            TO_DATE('#{startDateStr}', 'YYYYMMDD HH24:MI:SS'),
            TO_DATE('#{updateAtStr}', 'YYYYMMDD HH24:MI:SS'),
            '#{escape_char(tags)}'
        )
        ON CONFLICT(case_no)
        DO UPDATE SET 
          case_status = '#{escape_char(status)}',
          description = '#{escape_char(description)}',
          incident_type = '#{escape_char(incidentType)}',
          case_owner = '#{escape_char(owner)}',

          case_ref_id = '#{escape_char(id)}',
          case_title = '#{escape_char(title)}',
          case_pap = '#{escape_char(pap)}',
          case_severity = '#{escape_char(severity)}',
          case_summary = '#{escape_char(summary)}',
          update_by = '#{escape_char(updatedBy)}',
          solution_status = '#{escape_char(resolutionStatus)}',
          case_tlp = '#{escape_char(tlp)}',
          impact_status = '#{escape_char(impactStatus)}',
          start_date = TO_DATE('#{startDateStr}', 'YYYYMMDD HH24:MI:SS'),
          update_at = TO_DATE('#{updateAtStr}', 'YYYYMMDD HH24:MI:SS'),
          tags = '#{escape_char(tags)}'
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

hiveHost = ENV['HIVE_HOST']
caseCount = ENV['HIVE_CASE_COUNT']

# ใส่ข้อมูล TheHive server
thehive_url = "http://#{hiveHost}/index.html#/login"
username = ENV['HIVE_USER']
password = ENV['HIVE_PASSWORD']

puts("DEBUG : Calling URL [#{thehive_url}]...")
# เปิด browser (headless mode)
browser = Watir::Browser.new(:chrome, headless: true)
browser.goto(thehive_url)

# รอให้ input ปรากฏ (กันโหลดไม่ทัน)
browser.text_field(placeholder: 'Login').wait_until(&:present?)
browser.text_field(placeholder: 'Password').wait_until(&:present?)

# กรอก username + password
browser.text_field(placeholder: 'Login').set(username)
browser.text_field(placeholder: 'Password').set(password)

# คลิกปุ่ม login
browser.button(text: /Sign In/i).click

browser.goto("http://#{hiveHost}")
sleep 3

getCasesUrl = "http://#{hiveHost}/api/case?range=0-#{caseCount}"
browser.goto("#{getCasesUrl}")
sleep 3

puts("DEBUG : Getting cases from URL [#{getCasesUrl}]...")

jsonStr = browser.text
prettyJsonStr = JSON.pretty_generate(JSON.parse(jsonStr))
#puts(prettyJsonStr)
# ปิด browser
browser.close


pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")

arr = JSON.parse(prettyJsonStr)
seq = 0

arr.each do |incident|
  seq = seq + 1
  upsertData(conn, incident, seq)
end


