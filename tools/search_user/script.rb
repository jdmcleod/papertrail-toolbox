#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path("../..", __dir__)
require "bundler/setup"
Bundler.require

require "time"
require "dotenv/load"
require_relative "../../lib/papertrail_client"
require_relative "../../lib/event_cache"
require_relative "../../lib/event_fetcher"
require_relative "log_analyzer"
require_relative "report"

token = ENV.fetch("PAPERTRAIL_API_TOKEN")
user_id = ENV.fetch("TARGET_USER_ID")
start_time = Time.parse(ENV.fetch("START_DATE"))
end_time = Time.parse(ENV.fetch("END_DATE"))

client = PapertrailClient.new(token: token)
cache = EventCache.new(File.join(root, "log_cache"))
fetcher = EventFetcher.new(client: client, cache: cache)

puts "Fetching logs (#{start_time.strftime('%Y-%m-%d')} to #{end_time.strftime('%Y-%m-%d')})..."
events = fetcher.fetch(start_time: start_time, end_time: end_time)
puts "Total events loaded: #{events.length}"
puts

matches = LogAnalyzer.new(user_id).correlate(events)
Report.new(user_id, matches).print
