# frozen_string_literal: true

class Report
  def initialize(user_id, matches)
    @user_id = user_id
    @matches = matches
    @client_ips = group_by_ip
  end

  def print
    print_header
    return print_empty if @matches.empty?

    print_ip_summary
    print_ip_warning
    print_timeline
  end

  private

  def group_by_ip
    @matches.each_with_object(Hash.new { |h, k| h[k] = [] }) do |match, ips|
      ips[match.client_ip] << match.timestamp
    end
  end

  def print_header
    puts "=" * 70
    puts "Results for user_id=#{@user_id}"
    puts "=" * 70
    puts "Total requests found: #{@matches.length}"
    puts
  end

  def print_empty
    puts "No activity found for user_id=#{@user_id}."
  end

  def print_ip_summary
    puts "Client IPs:"
    @client_ips.each do |ip, timestamps|
      puts "  #{ip} — #{timestamps.length} request(s), #{timestamps.min} to #{timestamps.max}"
    end
  end

  def print_ip_warning
    known_ips = @client_ips.keys.reject { |ip| ip == "unknown" }
    return unless known_ips.length > 1

    puts
    puts "⚠  user_id=#{@user_id} seen from #{known_ips.length} distinct IPs:"
    known_ips.each { |ip| puts "    #{ip}" }
  end

  def print_timeline
    puts
    puts "Request timeline:"
    @matches.each do |m|
      puts "  [#{m.timestamp}] IP=#{m.client_ip} #{m.source}"
      puts "    #{m.detail}"
    end
  end
end
