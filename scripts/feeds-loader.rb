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
csv_url = "https://docs.google.com/spreadsheets/d/#{sheetKey}/export?format=csv&gid=2093750146"
#csv_url = "https://docs.google.com/spreadsheets/d/#{sheetKey}/export?format=csv&gid=422684088"

# อ่านไฟล์จาก URL
multiline_string = URI.open(csv_url).read

#multiline_string = File.read("news.csv")
line_no = 0
csv_content = ""

multiline_string.each_line do |line|
  line_no = line_no + 1
  if (line_no <= 2)
    next
  end

  csv_content = csv_content + line
end

#puts(csv_content)

# แปลงเป็นแถว ๆ
CSV.parse(csv_content, headers: false, quote_char: '"', row_sep: :auto).each_with_index do |row, index|
  #puts "Row #{index + 1}: #{row.inspect}"
  puts "==="
  puts "Row #{index + 1}: #{row[3]}"
end
