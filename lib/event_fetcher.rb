# frozen_string_literal: true

require "time"

class EventFetcher
  def initialize(client:, cache:)
    @client = client
    @cache = cache
  end

  def fetch(start_time:, end_time: Time.now)
    download_archives(start_time: start_time, end_time: end_time)
    @cache.read_all
  end

  private

  def download_archives(start_time:, end_time:)
    puts "Listing available archives..."
    archives = @client.archives(start_time: start_time, end_time: end_time)
    pending = archives.reject { |a| @cache.exists?(a["name"]) }

    puts "#{archives.length} total archives, #{pending.length} to download"

    pending.each_with_index do |archive, i|
      puts "  [#{i + 1}/#{pending.length}] #{archive['name']}"
      data = @client.download_archive(archive["downloadUrl"])
      @cache.write_archive(archive["name"], data)
    rescue RuntimeError => e
      retry if e.message == "rate_limited"
      raise
    end
  end
end
