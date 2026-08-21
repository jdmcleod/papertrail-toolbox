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
require_relative "report"

query = ARGV[0]
abort "Usage: bundle exec ruby tools/search_string/script.rb <search_string>" if query.nil? || query.empty?

token = ENV.fetch("PAPERTRAIL_API_TOKEN")
start_time = Time.parse(ENV.fetch("START_DATE"))
end_time = Time.parse(ENV.fetch("END_DATE"))

client = PapertrailClient.new(token: token)
cache = EventCache.new(File.join(root, "log_cache"))
fetcher = EventFetcher.new(client: client, cache: cache)

puts "Fetching logs (#{start_time.strftime('%Y-%m-%d')} to #{end_time.strftime('%Y-%m-%d')})..."
events = fetcher.fetch(start_time: start_time, end_time: end_time)
puts "Total events loaded: #{events.length}"
puts

matches = events.select { |event| (event["logmsg"] || "").include?(query) }
Report.new(query, matches).print
