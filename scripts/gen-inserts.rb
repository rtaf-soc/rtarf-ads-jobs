#!/usr/bin/env ruby

# Read file and insert line by line
File.foreach('../config/sha256.cfg') do |line|
  value = line.strip
  next if value.empty?

  tableName = "\"Blacklists\""
  puts("INSERT INTO #{tableName} (blacklist_id, org_id, blacklist_code, blacklist_type, tags, created_date) VALUES (gen_random_uuid(), 'default', '#{value}', 4, 'Imported from Github', CURRENT_TIMESTAMP);")
end

#puts "Data inserted successfully."
