#!/usr/bin/env ruby
require 'time'
require 'ostruct'
require 'yaml'

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

  def photos_per_month
    per_month_list  = stats_by_taken(:month)
    per_month_count = []

    per_month_list.each do |month, photos|
      per_month_count << [month, photos.count]
    end

    report per_month_count
  end

  def photos_per_day_of_week
    per_dow_list  = stats_by_taken(:day_of_week)
    per_dow_count = []

    per_dow_list.each do |dow, photos|
      per_dow_count << [dow, photos.count]
    end

    report per_dow_count
  end

  def photos_per_subject
    per_subject = {}
    @photo_details.each do |detail|
      per_subject[detail[:subject]] ||= 0
      per_subject[detail[:subject]] += 1
    end

    report per_subject.to_a
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

    parse = true
    format = case granularity
    when :time
      '%Y-%m-%d %H:%M:%S'
    when :day
      '%Y-%m-%d'
    when :month
      '%Y-%m-01'
    when :day_of_week
      parse = false
      '%A'
    else
      fail "unhandled"
    end
    grouped = @photo_details.group_by do |detail|
      if detail[:taken_at]
        detail = detail[:taken_at].strftime(format)
        parse ? Time.parse(detail) : detail
      end
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
    match = filename.match(/^(\d+)-(\d+)-(\d+) (\d+).(\d+).(\d+)\b.*/)
    return nil unless match
    Time.parse(
      "#{match[1]}/#{match[2]}/#{match[3]} #{match[4]}:#{match[5]}:#{match[6]}"
    )
  end

  def get_subject(filename)
    name = filename.match(/([^\-]*\s+-\s+)([^ \.]+)/)[2] rescue ''
    @known_subjects ||= YAML.load_file(File.join(File.dirname(__FILE__), 'subjects.yml')) rescue []
    @known_subjects.include?(name) ?
      name : nil
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
  stats.photos_per_month
else
  usage
end
