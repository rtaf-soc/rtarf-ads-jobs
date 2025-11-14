#!/usr/bin/env ruby

require 'pg'
require 'time'
require 'uri'
require 'redis'
require 'json'
require './utils'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true

def get_available_nodes(conn)
  sql = <<-SQL
    SELECT *
    FROM "Nodes" ORDER BY layer;
  SQL

  result = conn.exec(sql)

  rows = []

  result.each do |row|
    # แปลงคีย์จาก string เป็น symbol เพื่อใช้งานสะดวก
    obj = row.transform_keys(&:to_sym)
    rows << obj
  end

  return rows
end

def update_node_status(conn, node, nodeStatus)

  nodeId = node[:node_id]
  layer = node[:layer]

  sql = <<-SQL
    INSERT INTO "NodeStatus" (
      node_status_id,
      org_id,
      node_id,
      layer,
      status,
      created_date,
      updated_date
    )
    VALUES (
      gen_random_uuid(), 'default', $1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
    ON CONFLICT (org_id, node_id)
    DO UPDATE SET
      status = $3,
      updated_date = CURRENT_TIMESTAMP;
  SQL

  params = [
    nodeId,
    layer,
    nodeStatus,
  ]

  conn.exec_params(sql, params)
end

def get_node_status(node)
  highCount = rand(0..2)
  mediumCount = rand(0..2)
  lowCount = rand(0..2)

  threatCount = highCount + mediumCount + lowCount

  isAlert = "false"
  if (threatCount > 3)
    isAlert = "true"
  end

  statusObj = {
    IsAlert: isAlert,
    ThreatCount: threatCount,
    ThreatLevelHighCount: highCount,
    ThreatLevelMediumCount: mediumCount,
    ThreatLevelLowCount: lowCount,
  }

  json_str = statusObj.to_json
  return json_str
end

environment = ENV['ENVIRONMENT']

puts("INFO : ### Start node status update job.")
puts("INFO : ### ENVIRONMENT=[#{environment}]")

pgHost = ENV["PG_HOST"]
pgDb = ENV["PG_DB"]
conn = connect_db(pgHost, pgDb, ENV["PG_USER"], ENV["PG_PASSWORD"])
if (conn.nil?)
  puts("ERROR : ### Unable to connect to PostgreSQL --> Host=[#{pgHost}], DB=[#{pgDb}] !!!")
  exit 101
end
puts("INFO : ### Connected to PostgreSQL [#{pgHost}] [#{pgDb}]")

nodes = get_available_nodes(conn)
cnt = 0
nodes.each do |node|
  nodeName = node[:name]
  layer = node[:layer]

  puts("Updating node [#{nodeName}] layer [#{layer}]")

  nodeStatus = get_node_status(node)
  update_node_status(conn, node, nodeStatus)

  cnt = cnt+1
end

puts("Done updating [#{cnt}] node(s)")
