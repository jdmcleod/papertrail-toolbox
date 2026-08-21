# frozen_string_literal: true

class Report
  def initialize(query, matches)
    @query = query
    @matches = matches
  end

  def print
    puts "=" * 80
    puts "Search results for #{@query.inspect}: #{@matches.length} matching events"
    puts "=" * 80

    print_source_summary
    print_timeline
  end

  private

  def print_source_summary
    counts = @matches.group_by { |e| source_of(e) }.transform_values(&:length)
    return if counts.empty?

    puts
    puts "Events by source:"
    counts.sort_by { |_, count| -count }.each do |source, count|
      puts "  #{source}: #{count}"
    end
  end

  def print_timeline
    puts
    @matches.sort_by { |e| timestamp_of(e).to_s }.each do |event|
      puts "[#{timestamp_of(event)}] #{source_of(event)}"
      puts "  #{event['logmsg']}"
    end
  end

  def source_of(event)
    event["source_name"] || event["syslog_appname"] || "unknown"
  end

  def timestamp_of(event)
    event.dig("syslog", "timestamp")
  end
end
