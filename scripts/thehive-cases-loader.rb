#!/usr/bin/env ruby

require 'json'
require 'watir'
require 'pg'

require './utils'

if File.exist?('env.rb')
  #Default environment variables
  require './env'
end

$stdout.sync = true

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

puts prettyJsonStr

# ปิด browser
browser.close
