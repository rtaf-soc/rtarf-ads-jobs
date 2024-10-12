#!/usr/bin/env ruby

require 'json'

$stdout.sync = true

bucket = ARGV[0]
jsonFilePath = ARGV[1]
outputDir = ARGV[2]

puts("DEBUG - Bucket [#{bucket}]")
puts("DEBUG - File list JSON [#{jsonFilePath}]")
puts("DEBUG - Output directory [#{outputDir}]")
