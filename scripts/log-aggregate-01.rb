#!/usr/bin/env ruby

require 'json'
require "base64"
require 'net/http'
require './utils'
require 'elasticsearch'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true

puts("INFO - Starting program to aggregate log from ES and insert into PostgreSQL")
mode = ENV['MODE']

host = ENV["ES_HOST"]
port = ENV["ES_PORT"]
user = ENV["ES_USER"]
password = ENV["ES_PASSWORD"]

client = Elasticsearch::Client.new(
  hosts:
	  [
  	  {
    	  host: host,
    	  port: port,
    	  user: user,
    	  password: password,
    	  scheme: 'https'
  	  }
	  ]
)

response = client.search(index: 'proxy-analytic-*', scroll: '10m', body: { query: { match: { gtt_host: 'nginx-proxy-001-filebeat' } } })
scrollId = response['_scroll_id']

totalLoad = 0
while response['hits']['hits'].size.positive?
  response = client.scroll(scroll: '5m', body: { scroll_id: scrollId })
  #puts(response['hits']['hits'].map { |r| r['_source']['data']['uri'] })

  totalLoad = totalLoad + 1
end

puts("INFO : ### Done loading [#{totalLoad}] records to PostgreSQL\n")
