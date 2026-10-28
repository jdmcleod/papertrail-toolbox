#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path("../..", __dir__)
require "bundler/setup"
Bundler.require

require "dotenv/load"
require_relative "../../lib/papertrail_client"
require_relative "../../lib/event_cache"
require_relative "../../lib/event_fetcher"
require_relative "../../lib/time_window"
require_relative "log_analyzer"
require_relative "report"

window = TimeWindow.parse!(ARGV)
token = ENV.fetch("PAPERTRAIL_API_TOKEN")

client = PapertrailClient.new(token: token)
cache = EventCache.for_app(root)
fetcher = EventFetcher.new(client: client, cache: cache)

puts "Fetching #{ENV.fetch('APP_NAME')} logs (#{window})..."
events = fetcher.fetch(window)
puts "Total events loaded: #{events.length}"

Report.new(LogAnalyzer.new(events), window).print
