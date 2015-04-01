#!/usr/bin/env ruby
require 'time'
require 'ostruct'

def usage
  puts <<-USAGE
Compiles (mostly date/time-based) statistics about photos/videos in a folder.

usage: photo_stats.rb directory

USAGE
end

class PhotoStats
  attr_accessor :photo_dir, :photo_stats

  def initialize(photo_dir)
    @photo_details = PhotoDetailGetter.new(photo_dir).get_details
  end

  def days_with_no_photos
    by_taken = stats_by_taken(:day)
    days = by_taken.keys.sort

    last_day = [days.last, Time.new(Time.now.year, Time.now.month, Time.now.day)].min
    current_day = days.first

    no_photos = []
    while current_day <= last_day
      no_photos << [current_day] if !by_taken.include?(current_day)

      next_day = Time.new(current_day.year, current_day.month, current_day.day + 1) rescue nil
      next_day ||= Time.new(current_day.year, current_day.month + 1, 1) rescue nil
      next_day ||= Time.new(current_day.year + 1, 1, 1) rescue nil
      fail if next_day.nil?
      current_day = next_day
    end

    report no_photos
  end

  def photos_per_day
    per_day_list  = stats_by_taken(:day)
    per_day_count = []
    top_10 = []

    per_day_list.each do |day, photos|
      per_day_count << [day, photos.count]
    end

    top_10 = per_day_count.sort_by { |r| r[1] }.reverse[0..10]

    report per_day_count

    report top_10
  end

  private

  def report(table)
    table.each do |row|
      puts Array(row).inspect
    end
  end

  def stats_by_taken(granularity)
    @stats_by_taken ||= {}
    return @stats_by_taken[granularity] if @stats_by_taken[granularity]

    format = case granularity
    when :time
      '%Y-%m-%d %H:%M:%S'
    when :day
      '%Y-%m-%d'
    when :day_of_week
      '%u'
    else
      fail "unhandled"
    end
    grouped = @photo_details.group_by do |detail|
      detail[:taken_at] &&
      Time.parse(detail[:taken_at].strftime(format))
    end
    grouped.delete(nil)

    @stats_by_taken[granularity] = grouped
  end
end

# Compile stats given a directoy of photos
class PhotoDetailGetter
  include Enumerable

  attr_accessor :photo_dir, :photo_details

  def initialize(photo_dir)
    @photo_dir = File.expand_path(photo_dir)
    ensure_dir_exists

    @photo_details = []
    @errors = []
  end

  def get_details
    each do |file_path|
      @photo_details << split_path(file_path)
    end

    unless @errors.empty?
      @errors.each do |err|
        puts "#{err.class} : #{err.message}"
        puts err.backtrace
        puts '------------'
      end
    end

    @photo_details
  end

  def each
    Dir.glob(File.join(photo_dir, '**/*')).each do |file|
      next if File.directory?(file)
      yield(file)
    end
  rescue
    @errors << $!
  end

  private

  def split_path(path)
    file = File.basename(path)
    OpenStruct.new(
      taken_at: get_taken_at(file),
      subject: get_subject(file),
      ext: File.extname(file)
    )
  end

  def get_taken_at(filename)
    Time.parse(filename.gsub(
      /(\d+)-(\d+)-(\d+) (\d+).(\d+).(\d+)\b.*/,
      '\1/\2/\3 \4:\5:\6'
    )) rescue nil
  end

  def get_subject(filename)
    name = filename.match(/([^\-]*\s*-\s*)(\S+)/)[2] rescue ''
  end

  def ensure_dir_exists
    return if File.exists?(photo_dir)
    warn "The given photo dir doesn't exist: #{photo_dir}"
    exit 1
  end
end

case ARGV.size
when 1
  stats = PhotoStats.new(ARGV[0])
  stats.photos_per_day
else
  usage
end
