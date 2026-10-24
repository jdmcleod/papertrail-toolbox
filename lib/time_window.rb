# frozen_string_literal: true

require "optparse"
require "time"

class TimeWindow
  DEFAULT_HOURS = 24

  attr_reader :start_time, :end_time

  def self.parse!(argv, now: Time.now)
    options = { hours: DEFAULT_HOURS }
    OptionParser.new do |opts|
      opts.on("--from TIME", "Start of window (any Time.parse format)") { |v| options[:from] = Time.parse(v) }
      opts.on("--to TIME", "End of window (default: now)") { |v| options[:to] = Time.parse(v) }
      opts.on("--hours N", Integer, "Window length when --from is omitted (default: #{DEFAULT_HOURS})") { |v| options[:hours] = v }
    end.parse!(argv)

    end_time = options[:to] || now
    start_time = options[:from] || (end_time - (options[:hours] * 3600))
    new(start_time, end_time)
  end

  def initialize(start_time, end_time)
    raise ArgumentError, "start must be before end" unless start_time < end_time

    @start_time = start_time
    @end_time = end_time
  end

  def to_s
    "#{start_time.strftime('%Y-%m-%d %H:%M')} to #{end_time.strftime('%Y-%m-%d %H:%M')}"
  end
end
