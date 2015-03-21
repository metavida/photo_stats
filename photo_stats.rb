#!/usr/bin/env ruby
require 'time'

# Compile stats given a directoy of photos
class PhotoStats
  include Enumerable

  attr_accessor :photo_dir

  def initialize(photo_dir)
    @photo_dir = File.expand_path(photo_dir)
    ensure_dir_exists
  end

  def compile_stats
    each do |file_path|
      file = File.basename(file_path)
      taken_at = Time.parse(file.gsub(
        /(\d+)-(\d+)-(\d+) (\d+).(\d+).(\d+)\b.*/,
        '\1/\2/\3 \4:\5:\6'
      ))
      puts taken_at
    end
  end

  def each
    Dir.glob(File.join(photo_dir, '**/*')).each do |file|
      next if File.directory?(file)
      yield(file)
    end
  end

  private

  def ensure_dir_exists
    return if File.exists?(photo_dir)
    warn "The given photo dir doesn't exist: #{photo_dir}"
    exit 1
  end
end

def usage
  puts <<-USAGE
usage: photo_stats.rb path_to_photo_dir
USAGE
end

case ARGV.size
when 1
  stats = PhotoStats.new(ARGV[0])
  stats.compile_stats
else
  usage
end
