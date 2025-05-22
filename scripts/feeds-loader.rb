#!/usr/bin/env ruby

require 'pg'
require 'time'
require 'uri'
require 'open-uri'
require 'csv'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true

sheetKey = ENV['GOOGLE_SHEET_KEY1']

# จะต้องเป็น URL ที่ export?format-csv
threatSheetUrl = "https://docs.google.com/spreadsheets/d/#{sheetKey}/export?format=csv&gid=2093750146"
threatSheetSkip = 2

feedSheetUrl = "https://docs.google.com/spreadsheets/d/#{sheetKey}/export?format=csv&gid=930466582"
feedSheetSkip = 1

def getContent(url, numSkipLine)
  # อ่านไฟล์จาก URL
  multiline_string = URI.open(url).read

  line_no = 0
  csv_content = ""

  multiline_string.each_line do |line|
    line_no = line_no + 1
    if (line_no <= numSkipLine)
      next
    end

    csv_content = csv_content + line
  end

  return csv_content
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

def escape_char(str)
  return "#{str}".tr("'", "")
end

def upsertData1(dbConn, obj, seq)
  eventNo = obj[0]
  eventDate = obj[1]
  incidentType = obj[2]
  description = obj[3]
  targetAddress = obj[4]
  action = obj[5]
  owner = obj[6]
  detector = obj[7]

  orgId = "default"
  
  puts("INFO - Insert data to DB upsertData1() [#{eventNo}]")

  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"Threats\" 
        (
            threat_id,
            event_no,
            event_date_str,
            incident_type,
            org_id,
            description,
            target_address,
            action,
            owner,
            detected_by,
            created_date
        )
        VALUES
        (
            gen_random_uuid(),
            '#{escape_char(eventNo)}',
            '#{escape_char(eventDate)}',
            '#{escape_char(incidentType)}',
            '#{escape_char(orgId)}',
            '#{escape_char(description)}',
            '#{escape_char(targetAddress)}',
            '#{escape_char(action)}',
            '#{escape_char(owner)}',
            '#{escape_char(detector)}',
            CURRENT_TIMESTAMP
        )
        ON CONFLICT(event_no)
        DO UPDATE SET 
          incident_type = '#{escape_char(incidentType)}',
          event_date_str = '#{escape_char(eventDate)}',
          description = '#{escape_char(description)}',
          target_address = '#{escape_char(targetAddress)}',
          action = '#{escape_char(action)}',
          owner = '#{escape_char(owner)}',
          detected_by = '#{escape_char(detector)}'
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData1() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

def upsertData2(dbConn, obj, seq)
  feedNo = obj[0]
  feedDate = obj[1]
  feedType = obj[2]
  status = obj[3]
  description = obj[4]
  comment = obj[5]
  feedSource = obj[6]

  orgId = "default"
  
  puts("INFO - Insert data to DB upsertData2() [#{feedNo}]")

  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"NewsFeed\" 
        (
            feed_id,
            feed_no,
            feed_date_str,
            feed_type,
            status,
            org_id,
            description,
            comment,
            feed_source,
            created_date
        )
        VALUES
        (
            gen_random_uuid(),
            '#{escape_char(feedNo)}',
            '#{escape_char(feedDate)}',
            '#{escape_char(feedType)}',
            '#{escape_char(status)}',
            '#{escape_char(orgId)}',
            '#{escape_char(description)}',
            '#{escape_char(comment)}',
            '#{escape_char(feedSource)}',
            CURRENT_TIMESTAMP
        )
        ON CONFLICT(feed_no)
        DO UPDATE SET
          feed_type = '#{escape_char(feedType)}',
          status = '#{escape_char(status)}',
          feed_date_str = '#{escape_char(feedDate)}',
          description = '#{escape_char(description)}',
          comment = '#{escape_char(comment)}',
          feed_source = '#{escape_char(feedSource)}'
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData2() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")

##### Threat
csvContent = getContent(threatSheetUrl, threatSheetSkip)
totalRow = 0
CSV.parse(csvContent, headers: false, quote_char: '"', row_sep: :auto).each_with_index do |row, index|
  #puts(row.inspect)
  upsertData1(conn, row, index)
  totalRow = totalRow + 1
end

puts("INFO : ### Done upserting [#{totalRow}] rows of threat summary.")


##### NewsFeed
csvContent = getContent(feedSheetUrl, feedSheetSkip)
totalRow = 0
CSV.parse(csvContent, headers: false, quote_char: '"', row_sep: :auto).each_with_index do |row, index|
  #puts(row.inspect)
  upsertData2(conn, row, index)
  totalRow = totalRow + 1
end

puts("INFO : ### Done upserting [#{totalRow}] rows of news feed.")
