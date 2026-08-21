#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path("../..", __dir__)
require "bundler/setup"
Bundler.require

require "dotenv/load"
require_relative "../../lib/event_cache"
require_relative "html_report"

request_ids = ARGV
abort "Usage: bundle exec ruby tools/request_logs/script.rb <request_id> [request_id ...]" if request_ids.empty?

cache = EventCache.new(File.join(root, "log_cache"))
puts "Loading cached logs..."
events = cache.read_all
puts "Total events loaded: #{events.length}"

grouped = request_ids.to_h do |rid|
  matches = events.select do |event|
    (event["logmsg"] || "").include?(rid) || event.dig("heroku", "request_id") == rid
  end
  [rid, matches.sort_by { |e| e["time"].to_i }]
end

grouped.each { |rid, matches| puts "  #{rid}: #{matches.length} log lines" }

output_path = File.join(root, "visualizations", "request_logs.html")
File.write(output_path, HtmlReport.new(grouped).render)
puts "Report written to #{output_path}"
