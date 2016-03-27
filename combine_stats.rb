#!/usr/bin/env ruby
require 'time'

def usage(no_description: false)
  u = ''
  u += <<-DESC unless no_description
Given two or more directories containing CSV files produced by photo_stats.rb
Produces CSVs containing data from both years with each year in its own column.

DESC
  u += <<-USAGE
Usage:
    bundle exec ./combine_stats.rb <dst_dir> <year_1_dir> <year_2_dir> [<year_n_dir>..]

USAGE
  u
end

require 'optparse'

begin
  OptionParser.new do |opts|
    opts.banner = usage
    # Enforce that we don't currently support any options
  end.parse!
rescue OptionParser::InvalidOption
  puts $!.message; puts ''
  puts usage(no_description: true)
  exit 5
end

if ARGV.size >= 3
  CombineStats.run(*ARGV)
else
  puts "At least 3 directores must be provided as arguments, but only #{ARGV.size} were given."
  puts ''
  puts usage(no_description: true)
  exit 5
end
