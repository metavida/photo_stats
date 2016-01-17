#!/usr/bin/env ruby
require 'time'
require 'ostruct'
require 'yaml'
require 'fileutils'
require 'pry'

def usage
  <<-USAGE
Compiles (mostly date/time-based) statistics about photos/videos in a folder.

usage: photo_stats.rb directory

USAGE
end

def load_yml(name, fallback=nil)
  YAML.load_file(File.join(File.dirname(__FILE__), 'src', "#{name}.yml")) rescue fallback
end

class PhotoStats
  attr_accessor :photo_dir, :photo_stats, :options

  # Available options
  # :no_top_10: Default true
  def initialize(photo_dir, options={})
    options[:no_top_10] = true unless options.has_key?(:no_top_10)
    @options = options
    @photo_details = PhotoDetailGetter.new(photo_dir, options).get_details
  end

  def days_with_no_photos
    by_taken = stats_by_taken(:day)
    days = by_taken.keys.sort

    first_day = days.first
    # Either the last day listed or the end day (whichever is earlier)
    last_day = [days.last, get_day(:end)].min

    no_photos = ['date']
    each_day_between(first_day, last_day) do |current_day|
      no_photos << [current_day] if !by_taken.include?(current_day)
    end

    report 'no_photos', no_photos
  end

  def photos_per_day
    per_day_list  = stats_by_taken(:day).sort_by{ |day, photos| day }
    per_day_count = []

    cumulative_total = []
    per_day_list.each do |day, photos|
      per_day_count << [day, photos.count]

      prev_total = cumulative_total.last.last rescue 0
      cumulative_total << [day, prev_total + photos.count]
    end

    each_day_between(cumulative_total.last.first, get_day(:end)) do |current_day|
      prev = cumulative_total.last
      prev_day = prev.first
      prev_total = prev.last rescue 0
      cumulative_total << [current_day, prev_total+1]
    end

    report 'per_day', [['day', 'count']] + per_day_count
    report 'cumulative_total', [['day', 'count']] + cumulative_total

    unless options[:no_top_10]
      top_10 = []
      top_10 = per_day_count.sort_by { |r| r[1] }.reverse[0..10]
      report 'top_10', [['day', 'count', 'photo', 'note']] + top_10, :do_backup
    end
  end

  def photos_per_month
    per_month_list  = stats_by_taken(:month)
    per_month_count = [['month', 'count']]

    per_month_list.each do |month, photos|
      per_month_count << [month, photos.count]
    end

    report 'per_month', per_month_count
  end

  def photos_per_day_of_week
    per_dow_list  = stats_by_taken(:day_of_week)
    per_dow_count = [['day', 'count']]

    (1..7).each do |day|
      dow = Time.parse("2016-02-#{day}").strftime('%A')
      photos = per_dow_list[dow]
      per_dow_count << [dow, photos.count]
    end

    report 'per_day_of_week', per_dow_count
  end

  def photos_per_subject
    per_subject = {}
    @photo_details.each do |detail|
      per_subject[detail[:subject]] ||= 0
      per_subject[detail[:subject]] += 1
    end

    report 'per_subject', [['subject', 'count']] + per_subject.to_a
  end

  private

  def each_day_between(start_day, end_day)
    return if start_day == end_day

    current_day = start_day
    while current_day <= end_day
      yield(current_day)

      next_day = Time.new(current_day.year, current_day.month, current_day.day + 1) rescue nil
      next_day ||= Time.new(current_day.year, current_day.month + 1, 1) rescue nil
      next_day ||= Time.new(current_day.year + 1, 1, 1) rescue nil
      fail if next_day.nil?
      current_day = next_day
    end
  end

  def get_day(start_or_end)
    @dates ||= load_yml('dates', {})
    case start_or_end
    when :start
      Time.parse(@dates['start_day'])
    when :end
      Time.parse(@dates['end_day'])
    else
      fail ArgumentError.new("Expected :start or :end, but got #{start_or_end.inspect}")
    end
  end

  def report(filename, table, backup=false)
    path = File.expand_path(File.join(
      File.dirname(__FILE__), 'data', "#{filename}.csv"
    ))
    FileUtils.mkdir_p(File.dirname(path))

    if backup && File.exists?(path)
      FileUtils.mv(path, path.gsub(/.csv/, "#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.csv"))
    end

    File.open(path, 'w') do |file|
      table.each do |row|
        row = Array(row).map do |val|
          if val.respond_to?(:strftime)
            val.strftime("%d %b %Y %T %z")
          else
            val
          end
        end
        file.puts(row.join(','))
      end
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

  attr_accessor :photo_dir, :photo_details, :date_range

  def initialize(photo_dir, options = {})
    @photo_dir = File.expand_path(photo_dir)
    ensure_dir_exists

    year = options[:year].to_i
    year = 1 if options[:year] < 1

    @birthday = options[:birthday] if options[:birthday]

    if year == 1
      @date_range = (
        # Allow photos from the week leading up to birth
        birthday - 7*24*60*60 ...
        Time.new(birthday.year + 1, birthday.month, birthday.day+1)
      )
    else
      @date_range = (
        Time.new(birthday.year + year - 1, birthday.month, birthday.day) ...
        Time.new(birthday.year + year, birthday.month, birthday.day+1)
      )
    end

    @photo_details = []
    @errors = []
  end

  def birthday
    return @birthday if @birthday

    each do |file_path|
      details = split_path(file_path)
      if details[:taken_at] && (!@birthday || @birthday > details[:taken_at])
        @birthday = details[:taken_at]
      end
    end

    @birthday
  end

  def get_details
    each do |file_path|
      details = split_path(file_path)
      if details[:taken_at] && details[:taken_at] >= date_range.first && details[:taken_at] < date_range.last
        @photo_details << details
      end
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
    @known_subjects ||= load_yml('subjects', [])
    @known_subjects.include?(name) ?
      name : nil
  end

  def ensure_dir_exists
    return if File.exists?(photo_dir)
    warn "The given photo dir doesn't exist: #{photo_dir}"
    exit 1
  end
end

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = usage

  opts.on("-10", "--top10", "Generate a new top_10.csv") do |ten|
    options[:do_top_10] = !!ten
  end

  opts.on("-bDATE", "--birthday=DATE", "Their birthday") do |birthday|
    options[:birthday] = Time.parse(birthday.to_s) rescue nil
  end

  opts.on("-yYEAR", "--year=YEAR", "Generate data for a specific year of life (e.g. 1 == first 365 days of life)") do |year|
    options[:year] = year.to_i
  end
end.parse!

case ARGV.size
when 1
  stats = PhotoStats.new(ARGV[0],
                          no_top_10: !options[:do_top_10],
                          birthday:   options[:birthday],
                          year:       options[:year]
                        )
  stats.photos_per_subject
  stats.photos_per_day
  stats.photos_per_day_of_week
  stats.photos_per_month
  stats.days_with_no_photos
else
  puts usage
end
