#!/usr/bin/env ruby

# Read file and insert line by line
File.foreach('machines.txt') do |line|
  value = line.strip
  next if value.empty?

  tableName = "\"CsMachineStat\""
  puts("INSERT INTO #{tableName} (machine_stat_id, machine_name, last_cs_event_date) VALUES (gen_random_uuid(), '#{value}', CURRENT_TIMESTAMP);")
end

#puts "Data inserted successfully."
