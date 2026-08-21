# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class PapertrailClient
  BASE_URL = "https://api.na-01.cloud.solarwinds.com"

  def initialize(token:)
    @token = token
  end

  def archives(start_time:, end_time:)
    uri = URI("#{BASE_URL}/v1/logs/archives")
    uri.query = URI.encode_www_form(startTime: start_time.iso8601, endTime: end_time.iso8601)

    data = api_get(uri)
    data["logArchives"]
  end

  def download_archive(download_url)
    attempts = 0
    begin
      uri = URI(download_url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      handle_errors(response)
      response.body
    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout, EOFError => e
      attempts += 1
      raise if attempts > 3

      warn "  Network error (#{e.class}). Retrying in #{attempts * 2}s..."
      sleep(attempts * 2)
      retry
    end
  end

  private

  def api_get(uri)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    handle_errors(response)
    JSON.parse(response.body)
  end

  def handle_errors(response)
    return if response.is_a?(Net::HTTPSuccess)

    if response.code == "429"
      wait = (response["Retry-After"] || "5").to_i
      warn "  Rate limited. Waiting #{wait}s..."
      sleep(wait)
      raise "rate_limited"
    end

    abort "API error: #{response.code} #{response.message}\n#{response.body}"
  end
end
