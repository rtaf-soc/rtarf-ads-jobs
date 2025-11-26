#!/usr/bin/env ruby

require 'json'
require 'pg'
require 'time'
require 'zlib'
require 'stringio'
require 'rubygems/package'
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

def upsertData(dbConn, line, option)
  orgId = "default"
  ruleUrl = ENV['RULE_URL']

  name = option['msg'] || 'No Name'
  name = name.gsub(/\A"|"\z/, "")

  sid = option['sid'] || '0'
  rev = option['rev'] || '0'
  description = "Suricata rule with SID = [#{sid}]"
  tags = "SID=#{sid},Revision=#{rev}"

  # แสดงผล
  puts "SID [#{sid}], Name: #{name}"

  begin
    dbConn.transaction do |con|
        con.exec "INSERT INTO \"HuntingRules\" 
        (
            rule_id,
            org_id,
            rule_name,
            rule_description,
            rule_definition,
            ref_url,
            tags,
            ref_type,
            is_active,
            rule_created_date
        )
        VALUES
        (
            gen_random_uuid(),
            '#{escape_char(orgId)}',
            '#{escape_char(name)}',
            '#{escape_char(description)}',
            '#{escape_char(line)}',
            '#{escape_char(ruleUrl)}',
            '#{escape_char(tags)}',
            'Suricata',
            1,
            CURRENT_TIMESTAMP
        )
        ON CONFLICT(rule_name)
        DO UPDATE SET 
          rule_description = '#{escape_char(line)}',
          tags = '#{escape_char(tags)}'
        "
    end
  rescue PG::Error => e
    puts("ERROR - Insert data to DB upsertData() [#{e.message}]")
    exit 102 # Terminate immediately
  end
end

############# Main Program #############
puts("INFO - Starting program to load Suricata rules to PostgreSQL...")

mode = ENV['MODE']
pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]
ruleUrl = ENV['RULE_URL']
ruleUser = ENV['RULE_SERVER_USER']
rulePassword = ENV['RULE_SERVER_PASSWORD']
tmpDir = ENV['TMP_DIR'] || '/data/temp'

conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL!!! [#{pgHost}] [#{pgDb}]")
  exit 101
end

puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")

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

puts("INFO - Downloading rules file from [#{ruleUrl}]...")
uri = URI(ruleUrl)

Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
  request = Net::HTTP::Get.new(uri)
  request.basic_auth(ruleUser, rulePassword)

  http.request(request) do |response|
    if response.code.to_i != 200
      puts "Download failed: #{response.code} #{response.message}"
      exit
    end

    # อ่านทั้งหมดเป็น binary
    file_data = response.body

    puts "Download OK, extracting..."

    # -----------------------------
    # EXTRACT .tar.gz FROM MEMORY
    # -----------------------------
    tar_gz = StringIO.new(file_data)
    gz = Zlib::GzipReader.new(tar_gz)

    # อ่าน tar
    Gem::Package::TarReader.new(gz) do |tar|
      tar.each do |entry|
        if entry.file?
          puts "\n=== FILE: #{entry.full_name} ==="

          # อ่านทีละบรรทัด
          entry.read.each_line do |line|
            next unless line.start_with?("alert")

            if line =~ /^(\w+)\s+(\w+)\s+(\S+)\s+(\S+)\s+->\s+(\S+)\s+(\S+)\s*\((.*)\)/
              action      = $1           # alert
              protocol    = $2           # tcp
              src_ip      = $3           # $HOME_NET
              src_port    = $4           # any
              dst_ip      = $5           # $EXTERNAL_NET
              dst_port    = $6           # 69
              options_str = $7           # msg:"Test"; sid:1001; rev:1;

              # แปลง options เป็น hash
              options = {}
              options_str.split(';').each do |opt|
                next if opt.strip.empty?
                if opt =~ /^\s*(\w+)\s*:\s*(.*)\s*$/
                  key = $1
                  value = $2.strip
                  options[key] = value
                end
              end

              upsertData(conn, line, options)
            end
          end
        end
      end
    end
  end
end

